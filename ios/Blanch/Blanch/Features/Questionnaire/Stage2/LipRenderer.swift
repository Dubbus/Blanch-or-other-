import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Lip Renderer
//
// Composites a lipstick hex onto a user's photo inside a lip polygon.
// Strategy: build a soft alpha mask from the polygon, blend a tinted layer
// over the masked region using multiply/color blend modes so lip texture
// (shadows, highlights, lines) shows through.
//
// Pipeline:
//   1. Rasterize polygon → CGImage grayscale mask
//   2. Gaussian blur the mask edges (natural lipstick feather)
//   3. Build a tinted layer — source image multiplied by the lipstick color
//   4. Blend (tinted × mask) over original via CIBlendWithMask

protocol LipRendering: Sendable {
    func render(image: UIImage, lipPolygon: [CGPoint], hex: String) async throws -> UIImage
}

enum LipRendererError: Error, LocalizedError {
    case invalidImage
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not read that photo."
        case .renderFailed: return "Could not render the lipstick preview."
        }
    }
}

final class LipRenderer: LipRendering, Sendable {
    private let context: CIContext

    init() {
        // Software renderer — more reliable across sim + device than Metal
        // for a one-off composite like this. Performance is fine for still
        // photos.
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    func render(image: UIImage, lipPolygon: [CGPoint], hex: String) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw LipRendererError.invalidImage }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let mask = try buildSoftMask(polygon: lipPolygon, size: pixelSize)
        let sourceCI = CIImage(cgImage: cgImage)
        let tint = Self.ciColor(fromHex: hex)

        // Tinted layer: multiply the source image by the lipstick color.
        // This darkens the lips toward the shade while preserving texture.
        let colorLayer = CIImage(color: tint)
            .cropped(to: sourceCI.extent)

        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = colorLayer
        multiply.backgroundImage = sourceCI
        guard let tinted = multiply.outputImage else { throw LipRendererError.renderFailed }

        // Blend the tinted layer back onto the source using the soft mask
        // so only the lip region gets the treatment.
        let blend = CIFilter.blendWithMask()
        blend.inputImage = tinted
        blend.backgroundImage = sourceCI
        blend.maskImage = CIImage(cgImage: mask)
        guard let output = blend.outputImage else { throw LipRendererError.renderFailed }

        guard let rendered = context.createCGImage(output, from: sourceCI.extent) else {
            throw LipRendererError.renderFailed
        }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Mask

    // Rasterize the lip polygon into a grayscale mask, then gaussian blur
    // the edges for a natural feathered blend.
    private func buildSoftMask(polygon: [CGPoint], size: CGSize) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        let cs = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw LipRendererError.renderFailed }

        ctx.setFillColor(gray: 0, alpha: 1) // black background = masked out
        ctx.fill(CGRect(origin: .zero, size: size))

        guard polygon.count >= 3 else { throw LipRendererError.renderFailed }

        ctx.setFillColor(gray: 1, alpha: 1) // white polygon = lipstick applied
        ctx.beginPath()
        ctx.move(to: polygon[0])
        for p in polygon.dropFirst() { ctx.addLine(to: p) }
        ctx.closePath()
        ctx.fillPath()

        guard let raw = ctx.makeImage() else { throw LipRendererError.renderFailed }

        // Feather the edges so the lipstick blends naturally. Blur radius
        // scales with lip size (~2% of the smaller image dimension).
        let blurRadius = max(2.0, min(size.width, size.height) * 0.003)
        let ciInput = CIImage(cgImage: raw)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = ciInput
        blur.radius = Float(blurRadius)
        guard let blurred = blur.outputImage else { return raw }

        // Blur extends the image extent — clamp back to source extent.
        let clamped = blurred.cropped(to: ciInput.extent)
        return context.createCGImage(clamped, from: ciInput.extent) ?? raw
    }

    // MARK: - Color

    private static func ciColor(fromHex hex: String) -> CIColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        return CIColor(red: r, green: g, blue: b)
    }
}
