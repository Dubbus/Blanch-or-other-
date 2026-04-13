import Foundation

// MARK: - Color Space Converter
// Pure value type that converts between sRGB and CIE LAB.
// Used by the skin sampler (pixels → LAB) and the classifier
// (palette hex → LAB for Delta-E distance).
//
// Math: sRGB (gamma-corrected) → linear RGB → CIE XYZ (D65) → CIE LAB.

struct RGB: Sendable, Hashable {
    let r: Double  // 0...1
    let g: Double  // 0...1
    let b: Double  // 0...1
}

struct LAB: Sendable, Hashable {
    let l: Double  // 0...100
    let a: Double  // roughly -128...127
    let b: Double  // roughly -128...127

    var chroma: Double { (a * a + b * b).squareRoot() }
}

enum ColorSpaceConverter {
    // D65 white point
    private static let refX = 95.047
    private static let refY = 100.000
    private static let refZ = 108.883

    static func rgbToLab(_ rgb: RGB) -> LAB {
        let (x, y, z) = rgbToXYZ(rgb)
        return xyzToLab(x: x, y: y, z: z)
    }

    static func hexToLab(_ hex: String) -> LAB? {
        guard let rgb = hexToRGB(hex) else { return nil }
        return rgbToLab(rgb)
    }

    static func hexToRGB(_ hex: String) -> RGB? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return RGB(r: r, g: g, b: b)
    }

    private static func rgbToXYZ(_ rgb: RGB) -> (Double, Double, Double) {
        let r = linearize(rgb.r) * 100.0
        let g = linearize(rgb.g) * 100.0
        let b = linearize(rgb.b) * 100.0

        let x = r * 0.4124 + g * 0.3576 + b * 0.1805
        let y = r * 0.2126 + g * 0.7152 + b * 0.0722
        let z = r * 0.0193 + g * 0.1192 + b * 0.9505
        return (x, y, z)
    }

    private static func linearize(_ channel: Double) -> Double {
        channel > 0.04045
            ? pow((channel + 0.055) / 1.055, 2.4)
            : channel / 12.92
    }

    private static func xyzToLab(x: Double, y: Double, z: Double) -> LAB {
        let fx = labF(x / refX)
        let fy = labF(y / refY)
        let fz = labF(z / refZ)

        let l = (116.0 * fy) - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)
        return LAB(l: l, a: a, b: b)
    }

    private static func labF(_ t: Double) -> Double {
        t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t) + (16.0 / 116.0)
    }
}

// MARK: - Delta-E (CIE76)

enum DeltaECalculator {
    // CIE76 — simple Euclidean distance in LAB space.
    // Fast, good enough for v1 season matching. Can be swapped for CIE2000
    // later via a strategy without touching callers.
    static func cie76(_ a: LAB, _ b: LAB) -> Double {
        let dl = a.l - b.l
        let da = a.a - b.a
        let db = a.b - b.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
