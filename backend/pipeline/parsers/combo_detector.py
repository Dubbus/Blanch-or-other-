"""
Detect lip combo groupings from co-mentioned products.

When an influencer mentions multiple lip products in the same caption,
this module groups them into liner + lipstick + gloss combos.
"""

from pipeline.parsers.mention_extractor import extract_mentions, has_combo_signal

LIP_ROLES = {
    "liner": ["liner", "lip liner", "lip pencil"],
    "lipstick": ["lipstick", "lip", "stick", "matte ink", "lip paint"],
    "gloss": ["gloss", "lip gloss", "lip jelly", "luminizer"],
}


def detect_combos(mentions: list[dict]) -> list[dict]:
    """
    Given a list of product mentions from a single caption,
    try to group lip products into combos.

    Returns list of combo dicts, each with 'items' containing
    role-tagged product references.
    """
    lip_mentions = []
    for m in mentions:
        for role, keywords in LIP_ROLES.items():
            if m["keyword"] in keywords or any(k in m["context"].lower() for k in keywords):
                lip_mentions.append({**m, "role": role})
                break

    if len(lip_mentions) < 2:
        return []

    # Group all lip mentions into a single combo
    combo = {
        "items": [
            {"role": m["role"], "context": m["context"]}
            for m in lip_mentions
        ]
    }
    return [combo]
