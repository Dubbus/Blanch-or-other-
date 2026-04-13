import Foundation
import CoreImage
import CoreGraphics

// MARK: - Skin Sampler
// Given a detected face and source image, samples pixels from forehead,
// left cheek, right cheek, and jawline regions, converts them to LAB,
// and returns the averaged skin LAB plus per-region breakdown.
//
// Region placement is geometric (fractions of the face bounding box) rather
// than landmark-based — this is robust even when Vision returns sparse
// landmarks and keeps the math simple for v1.

protocol SkinSampling: Sendable {
    func sample(image: CIImage, face: DetectedFace, pixelSize: CGSize) throws -> SkinSample
}

struct SkinSample: Sendable {
    let averageLAB: LAB
    let regions: [RegionSample]
    let pixelsUsed: Int
}

struct RegionSample: Sendable {
    let name: String
    let rect: CGRect
    let lab: LAB
}

enum SkinSamplerError: Error, LocalizedError {
    case rasterizeFailed
    case noValidPixels

    var errorDescription: String? {
        switch self {
        case .rasterizeFailed: return "Couldn't read pixel data from the photo."
        case .noValidPixels: return "Couldn't find enough skin pixels to analyze."
        }
    }
}

final class SkinSampler: SkinSampling, Sendable {
    private let context: CIContext

    init(context: CIContext = CIContext(options: [.useSoftwareRenderer: false])) {
        self.context = context
    }

    func sample(image: CIImage, face: DetectedFace, pixelSize: CGSize) throws -> SkinSample {
        // Rasterize the full image once into a CGImage so we can index RGBA pixels.
        guard let cgImage = context.createCGImage(image, from: CGRect(origin: .zero, size: pixelSize)) else {
            throw SkinSamplerError.rasterizeFailed
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw SkinSamplerError.rasterizeFailed
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let regions = Self.regionRects(for: face.boundingBox, imageSize: CGSize(width: width, height: height))
        var regionSamples: [RegionSample] = []
        var accumulatedLAB = (l: 0.0, a: 0.0, b: 0.0)
        var totalPixels = 0

        for region in regions {
            let (lab, count) = Self.averageLAB(
                pixels: pixels,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                rect: region.rect
            )
            if count > 0 {
                regionSamples.append(RegionSample(name: region.name, rect: region.rect, lab: lab))
                accumulatedLAB.l += lab.l * Double(count)
                accumulatedLAB.a += lab.a * Double(count)
                accumulatedLAB.b += lab.b * Double(count)
                totalPixels += count
            }
        }

        guard totalPixels > 0 else { throw SkinSamplerError.noValidPixels }

        let avg = LAB(
            l: accumulatedLAB.l / Double(totalPixels),
            a: accumulatedLAB.a / Double(totalPixels),
            b: accumulatedLAB.b / Double(totalPixels)
        )
        return SkinSample(averageLAB: avg, regions: regionSamples, pixelsUsed: totalPixels)
    }

    // MARK: - Region placement
    //
    // Given a face bounding box (top-left pixel coordinates), carve out four
    // sampling rects as fractions of the box. These avoid the eyes, brows,
    // nostrils, and lips where color contamination is highest.

    private struct NamedRect {
        let name: String
        let rect: CGRect
    }

    private static func regionRects(for faceBox: CGRect, imageSize: CGSize) -> [NamedRect] {
        func subRect(xFraction: CGFloat, yFraction: CGFloat, wFraction: CGFloat, hFraction: CGFloat) -> CGRect {
            let rect = CGRect(
                x: faceBox.origin.x + faceBox.size.width * xFraction,
                y: faceBox.origin.y + faceBox.size.height * yFraction,
                width: faceBox.size.width * wFraction,
                height: faceBox.size.height * hFraction
            )
            return rect.intersection(CGRect(origin: .zero, size: imageSize))
        }

        return [
            NamedRect(name: "forehead",  rect: subRect(xFraction: 0.35, yFraction: 0.12, wFraction: 0.30, hFraction: 0.10)),
            NamedRect(name: "leftCheek", rect: subRect(xFraction: 0.15, yFraction: 0.55, wFraction: 0.18, hFraction: 0.12)),
            NamedRect(name: "rightCheek", rect: subRect(xFraction: 0.67, yFraction: 0.55, wFraction: 0.18, hFraction: 0.12)),
            NamedRect(name: "jawline",   rect: subRect(xFraction: 0.40, yFraction: 0.85, wFraction: 0.20, hFraction: 0.08)),
        ]
    }

    // MARK: - Pixel averaging

    private static func averageLAB(
        pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rect: CGRect
    ) -> (LAB, Int) {
        let minX = max(0, Int(rect.origin.x))
        let minY = max(0, Int(rect.origin.y))
        let maxX = min(width, Int(rect.origin.x + rect.size.width))
        let maxY = min(height, Int(rect.origin.y + rect.size.height))
        if minX >= maxX || minY >= maxY { return (LAB(l: 0, a: 0, b: 0), 0) }

        var rSum = 0.0
        var gSum = 0.0
        var bSum = 0.0
        var count = 0

        for y in minY..<maxY {
            for x in minX..<maxX {
                let offset = y * bytesPerRow + x * 4
                let r = Double(pixels[offset]) / 255.0
                let g = Double(pixels[offset + 1]) / 255.0
                let b = Double(pixels[offset + 2]) / 255.0
                let alpha = pixels[offset + 3]
                if alpha < 200 { continue }

                // Reject pixels that are clearly not skin: very dark, very bright,
                // or have neutral/blue cast (eyes, lips, shadows, background bleed).
                let brightness = (r + g + b) / 3.0
                if brightness < 0.12 || brightness > 0.97 { continue }
                if r < g || r < b { continue }  // skin is always red-dominant

                rSum += r
                gSum += g
                bSum += b
                count += 1
            }
        }

        guard count > 0 else { return (LAB(l: 0, a: 0, b: 0), 0) }
        let avgRGB = RGB(r: rSum / Double(count), g: gSum / Double(count), b: bSum / Double(count))
        return (ColorSpaceConverter.rgbToLab(avgRGB), count)
    }
}
