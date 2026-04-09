"""
CIE Delta-E color distance matching.

Maps product hex codes to color seasons by computing perceptual distance
between the product color and each season's palette colors in LAB space.
"""

import math


def hex_to_rgb(hex_code: str) -> tuple[int, int, int]:
    """Convert hex color string to RGB tuple."""
    h = hex_code.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb_to_lab(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Convert RGB to CIE LAB color space via XYZ."""
    # Normalize to 0-1
    var_r, var_g, var_b = r / 255.0, g / 255.0, b / 255.0

    # Linearize (inverse sRGB companding)
    var_r = ((var_r + 0.055) / 1.055) ** 2.4 if var_r > 0.04045 else var_r / 12.92
    var_g = ((var_g + 0.055) / 1.055) ** 2.4 if var_g > 0.04045 else var_g / 12.92
    var_b = ((var_b + 0.055) / 1.055) ** 2.4 if var_b > 0.04045 else var_b / 12.92

    # Convert to XYZ (D65 illuminant)
    x = (var_r * 0.4124564 + var_g * 0.3575761 + var_b * 0.1804375) / 0.95047
    y = (var_r * 0.2126729 + var_g * 0.7151522 + var_b * 0.0721750) / 1.00000
    z = (var_r * 0.0193339 + var_g * 0.1191920 + var_b * 0.9503041) / 1.08883

    # Convert XYZ to LAB
    epsilon = 0.008856
    kappa = 903.3

    fx = x ** (1 / 3) if x > epsilon else (kappa * x + 16) / 116
    fy = y ** (1 / 3) if y > epsilon else (kappa * y + 16) / 116
    fz = z ** (1 / 3) if z > epsilon else (kappa * z + 16) / 116

    l_star = 116 * fy - 16
    a_star = 500 * (fx - fy)
    b_star = 200 * (fy - fz)

    return l_star, a_star, b_star


def delta_e(lab1: tuple[float, float, float], lab2: tuple[float, float, float]) -> float:
    """CIE76 Delta-E: Euclidean distance in LAB space."""
    return math.sqrt(
        (lab1[0] - lab2[0]) ** 2
        + (lab1[1] - lab2[1]) ** 2
        + (lab1[2] - lab2[2]) ** 2
    )


def hex_to_lab(hex_code: str) -> tuple[float, float, float]:
    """Convert hex color to LAB."""
    return rgb_to_lab(*hex_to_rgb(hex_code))


def match_color_to_seasons(
    product_hex: str,
    seasons: list[dict],
) -> list[dict]:
    """
    Match a product hex code to color seasons.

    Args:
        product_hex: Product color as hex string (e.g., "#FF0000")
        seasons: List of season dicts with 'name' and 'hex_palette' keys

    Returns:
        List of dicts with 'season_name' and 'confidence' (0.0-1.0),
        sorted by confidence descending.
    """
    product_lab = hex_to_lab(product_hex)
    results = []

    for season in seasons:
        palette_labs = [hex_to_lab(h) for h in season["hex_palette"]]
        # Min distance to any color in the palette
        min_dist = min(delta_e(product_lab, pl) for pl in palette_labs)
        results.append({
            "season_name": season["name"],
            "min_distance": min_dist,
        })

    # Convert distance to confidence (inverse, normalized)
    max_dist = max(r["min_distance"] for r in results) or 1.0
    for r in results:
        # Closer distance = higher confidence, scaled 0-1
        r["confidence"] = round(max(0.0, 1.0 - (r["min_distance"] / max_dist)), 3)

    results.sort(key=lambda r: r["confidence"], reverse=True)
    return [{"season_name": r["season_name"], "confidence": r["confidence"]} for r in results]
