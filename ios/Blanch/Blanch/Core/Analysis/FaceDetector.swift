import Foundation
import Vision
import CoreImage

// MARK: - Face Detector
// Wraps Apple's Vision framework face landmark detection.
// Given a CIImage, returns the first detected face's landmarks + bounding box
// in image-pixel coordinates (origin top-left), ready for the skin sampler.

protocol FaceDetecting: Sendable {
    func detectFace(in cgImage: CGImage, pixelSize: CGSize) async throws -> DetectedFace
}

struct DetectedFace: Sendable {
    // Face bounding box in image pixel coordinates, origin top-left.
    let boundingBox: CGRect
    // Face contour landmark points in image pixel coordinates, origin top-left.
    // nil if Vision didn't return a face contour.
    let faceContour: [CGPoint]?
    // Detection confidence from Vision (0...1).
    let confidence: Float
}

enum FaceDetectionError: Error, LocalizedError {
    case noFaceFound
    case multipleFaces(count: Int)
    case visionError(Error)

    var errorDescription: String? {
        switch self {
        case .noFaceFound:
            return "We couldn't find a face in that photo. Try one with your face clearly visible and well-lit."
        case .multipleFaces(let count):
            return "We found \(count) faces in that photo. Please use a selfie with only your face."
        case .visionError(let error):
            return "Face detection failed: \(error.localizedDescription)"
        }
    }
}

final class FaceDetector: FaceDetecting, Sendable {
    func detectFace(in cgImage: CGImage, pixelSize: CGSize) async throws -> DetectedFace {
        // VNImageRequestHandler.perform is synchronous — the completion handler
        // fires during the perform call. If we resume the continuation from
        // inside the completion handler AND from the perform's catch block,
        // CheckedContinuation traps on double-resume. Capture the result in a
        // local Result and resume exactly once after perform returns.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DetectedFace, Error>) in
            var captured: Result<DetectedFace, Error>?

            // We use VNDetectFaceRectanglesRequest (not Landmarks) because the
            // Landmarks request fails on the iOS Simulator with "could not create
            // inference context" — it relies on Neural Engine compute that the sim
            // doesn't provide. Our skin sampler only needs the face bounding box,
            // which rectangles gives us reliably.
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    captured = .failure(FaceDetectionError.visionError(error))
                    return
                }

                guard let observations = request.results as? [VNFaceObservation], !observations.isEmpty else {
                    captured = .failure(FaceDetectionError.noFaceFound)
                    return
                }

                if observations.count > 1 {
                    captured = .failure(FaceDetectionError.multipleFaces(count: observations.count))
                    return
                }

                let face = observations[0]
                let boundingBox = Self.pixelRect(from: face.boundingBox, imageSize: pixelSize)

                captured = .success(DetectedFace(
                    boundingBox: boundingBox,
                    faceContour: nil,
                    confidence: face.confidence
                ))
            }

            // Pin to revision 1 — newer revisions use Neural Engine models that
            // fail on the iOS Simulator with "could not create inference context".
            request.revision = VNDetectFaceRectanglesRequestRevision1

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                captured = .failure(FaceDetectionError.visionError(error))
            }

            if let captured {
                continuation.resume(with: captured)
            } else {
                continuation.resume(throwing: FaceDetectionError.noFaceFound)
            }
        }
    }

    // Vision returns bounding boxes in normalized coordinates with origin
    // at the BOTTOM-left. Flip Y to get top-left pixel coordinates.
    private static func pixelRect(from normalized: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalized.origin.x * imageSize.width
        let width = normalized.size.width * imageSize.width
        let height = normalized.size.height * imageSize.height
        let y = (1.0 - normalized.origin.y - normalized.size.height) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

}
