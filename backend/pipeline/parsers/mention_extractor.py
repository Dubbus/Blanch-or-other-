"""
Extract product mentions from influencer captions/comments.

Searches for known product category keywords and attempts to match
brand + shade combinations.
"""

import re

PRODUCT_KEYWORDS = [
    "blush", "liner", "gloss", "combo", "foundation", "concealer",
    "mascara", "eyeliner", "brow", "contour", "bronzer", "tint",
    "spf", "primer", "lipstick", "lip", "stick",
]

KEYWORD_PATTERN = re.compile(
    r"\b(" + "|".join(PRODUCT_KEYWORDS) + r")\b",
    re.IGNORECASE,
)


def extract_mentions(text: str) -> list[dict]:
    """
    Extract product keyword mentions from a text snippet.

    Returns list of dicts with 'keyword', 'start', 'end', and 'context'
    (surrounding text snippet for manual review).
    """
    mentions = []
    for match in KEYWORD_PATTERN.finditer(text):
        start = max(0, match.start() - 40)
        end = min(len(text), match.end() + 40)
        mentions.append({
            "keyword": match.group().lower(),
            "start": match.start(),
            "end": match.end(),
            "context": text[start:end].strip(),
        })
    return mentions


def has_combo_signal(text: str) -> bool:
    """Check if text mentions a product combo/pairing."""
    combo_patterns = [
        r"combo",
        r"paired?\s+with",
        r"topped?\s+with",
        r"liner\s*\+\s*lip",
        r"lip\s*\+\s*gloss",
        r"liner.*lipstick.*gloss",
        r"on\s+(?:the\s+)?lips?.*:",
    ]
    for pattern in combo_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False
