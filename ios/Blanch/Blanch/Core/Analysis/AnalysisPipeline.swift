import Foundation
import CoreImage
import UIKit

// MARK: - Analysis Pipeline
// OOP Pattern: Template Method
//
// Orchestrates the full photo → season pipeline:
//   1. Load palettes (SeasonPaletteProviding)
//   2. Detect face  (FaceDetecting)
//   3. Sample skin  (SkinSampling)
//   4. Classify     (SeasonClassificationStrategy)
//
// Each step is injected as a protocol so every stage is independently mockable.
// The pipeline itself just wires them together — no Vision/CoreImage leakage
// upward into the ViewModel layer.

protocol AnalysisPipelining: Sendable {
    func run(on uiImage: UIImage) async throws -> AnalysisOutcome
}

struct AnalysisOutcome: Sendable {
    let skinSample: SkinSample
    let classification: SeasonClassification
    let faceBox: CGRect
    let imageSize: CGSize
}

enum AnalysisPipelineError: Error, LocalizedError {
    case invalidImage
    case paletteLoadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "That photo couldn't be read. Try another one."
        case .paletteLoadFailed(let error): return "Couldn't load season data: \(error.localizedDescription)"
        }
    }
}

final class AnalysisPipeline: AnalysisPipelining, Sendable {
    private let paletteProvider: SeasonPaletteProviding
    private let faceDetector: FaceDetecting
    private let skinSampler: SkinSampling
    private let classifier: SeasonClassificationStrategy

    init(
        paletteProvider: SeasonPaletteProviding = BundledSeasonPaletteProvider(),
        faceDetector: FaceDetecting = FaceDetector(),
        skinSampler: SkinSampling = SkinSampler(),
        classifier: SeasonClassificationStrategy = SkinToneAxisStrategy()
    ) {
        self.paletteProvider = paletteProvider
        self.faceDetector = faceDetector
        self.skinSampler = skinSampler
        self.classifier = classifier
    }

    func run(on uiImage: UIImage) async throws -> AnalysisOutcome {
        let palettes: [SeasonPalette]
        do {
            palettes = try paletteProvider.loadPalettes()
        } catch {
            throw AnalysisPipelineError.paletteLoadFailed(error)
        }

        // Normalize orientation so Vision sees an upright image, then convert
        // to CIImage. UIImage.pngData + reload gives us a CGImage with .up orientation.
        guard let normalized = uiImage.normalizedToUp(),
              let cgImage = normalized.cgImage else {
            throw AnalysisPipelineError.invalidImage
        }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let ciImage = CIImage(cgImage: cgImage)

        let face = try await faceDetector.detectFace(in: cgImage, pixelSize: pixelSize)
        let sample = try skinSampler.sample(image: ciImage, face: face, pixelSize: pixelSize)
        let classification = classifier.classify(skin: sample.averageLAB, palettes: palettes)

        return AnalysisOutcome(
            skinSample: sample,
            classification: classification,
            faceBox: face.boundingBox,
            imageSize: pixelSize
        )
    }
}

// MARK: - UIImage orientation helper

private extension UIImage {
    // Returns a copy of the image with orientation baked into the pixels.
    // Photos from PHPicker often carry EXIF orientation; Vision handles this
    // via the request handler, but our pixel-buffer sampling path wants an
    // upright image so the face bounding box lines up with the pixel grid.
    func normalizedToUp() -> UIImage? {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
