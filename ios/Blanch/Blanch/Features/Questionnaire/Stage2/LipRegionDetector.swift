import Foundation
import CoreGraphics
import Vision

// MARK: - Lip Region Detector
//
// Returns a lip-region polygon in image pixel coordinates (origin top-left).
// Two strategies:
//   1. Vision VNDetectFaceLandmarksRequest — accurate outer-lip polygon on device
//   2. Heuristic ellipse from the face bbox — fallback for iOS Simulator where
//      the Landmarks request fails ("could not create inference context").
//
// The detector tries landmarks first; on any failure it falls back to the
// heuristic so Stage 2 remains testable in the sim.

protocol LipRegionDetecting: Sendable {
    func detectLipRegion(in cgImage: CGImage, pixelSize: CGSize) async throws -> LipRegion
}

struct LipRegion: Sendable {
    // Polygon points in image pixel coordinates, origin top-left.
    let polygon: [CGPoint]
    // Tight bounding box around the polygon.
    let boundingBox: CGRect
    // True if polygon came from Vision landmarks; false for heuristic fallback.
    let isPrecise: Bool
}

enum LipRegionError: Error, LocalizedError {
    case noFaceFound
    case detectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noFaceFound:
            return "We couldn't find your lips in that photo. Try one with your face clearly visible."
        case .detectionFailed(let error):
            return "Lip detection failed: \(error.localizedDescription)"
        }
    }
}

final class LipRegionDetector: LipRegionDetecting, Sendable {
    private let faceDetector: FaceDetecting

    init(faceDetector: FaceDetecting = FaceDetector()) {
        self.faceDetector = faceDetector
    }

    func detectLipRegion(in cgImage: CGImage, pixelSize: CGSize) async throws -> LipRegion {
        if let precise = try? await detectLandmarks(in: cgImage, pixelSize: pixelSize) {
            return precise
        }
        // Fallback: face bbox → heuristic ellipse polygon
        let face = try await faceDetector.detectFace(in: cgImage, pixelSize: pixelSize)
        return heuristicLipRegion(faceBBox: face.boundingBox)
    }

    // MARK: - Landmarks path (device only — sim will throw and we'll fall back)

    private func detectLandmarks(in cgImage: CGImage, pixelSize: CGSize) async throws -> LipRegion {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LipRegion, Error>) in
            var captured: Result<LipRegion, Error>?

            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error {
                    captured = .failure(LipRegionError.detectionFailed(error))
                    return
                }
                guard let obs = (request.results as? [VNFaceObservation])?.first,
                      let outer = obs.landmarks?.outerLips else {
                    captured = .failure(LipRegionError.noFaceFound)
                    return
                }
                let bbox = obs.boundingBox
                let polygon = outer.normalizedPoints.map { p -> CGPoint in
                    // Landmark points are normalized to the face bbox.
                    let fx = bbox.origin.x + p.x * bbox.size.width
                    let fy = bbox.origin.y + p.y * bbox.size.height
                    // Flip Y — Vision origin is bottom-left, we want top-left.
                    return CGPoint(
                        x: fx * pixelSize.width,
                        y: (1.0 - fy) * pixelSize.height
                    )
                }
                let box = Self.boundingRect(of: polygon)
                captured = .success(LipRegion(polygon: polygon, boundingBox: box, isPrecise: true))
            }
            request.revision = VNDetectFaceLandmarksRequestRevision1

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                captured = .failure(LipRegionError.detectionFailed(error))
            }

            if let captured {
                cont.resume(with: captured)
            } else {
                cont.resume(throwing: LipRegionError.noFaceFound)
            }
        }
    }

    // MARK: - Heuristic fallback
    //
    // Given a face bounding box, approximate the outer-lip region as an
    // ellipse centered horizontally at 50% and vertically at 72% down from
    // the top of the bbox. Width ~38% of bbox width, height ~13% of bbox height.
    // Polygon sampled at 20 points around the ellipse.

    private func heuristicLipRegion(faceBBox: CGRect) -> LipRegion {
        // Lip position ratios calibrated against SkinSampler's landmark
        // math (forehead at 0.18, cheeks at 0.55) — lips sit around 0.80
        // of face-bbox height, centered horizontally, ~35% of face width
        // and ~9% of face height for the outer-lip ellipse.
        let cx = faceBBox.midX
        let cy = faceBBox.minY + faceBBox.height * 0.80
        let rx = faceBBox.width * 0.175
        let ry = faceBBox.height * 0.045

        let steps = 32
        let polygon: [CGPoint] = (0..<steps).map { i in
            let t = Double(i) / Double(steps) * 2.0 * .pi
            return CGPoint(x: cx + rx * cos(t), y: cy + ry * sin(t))
        }

        let box = CGRect(
            x: cx - rx, y: cy - ry,
            width: rx * 2, height: ry * 2
        )
        return LipRegion(polygon: polygon, boundingBox: box, isPrecise: false)
    }

    private static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
