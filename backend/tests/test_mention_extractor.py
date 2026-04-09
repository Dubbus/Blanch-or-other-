"""Tests for the mention extractor."""

from pipeline.parsers.mention_extractor import extract_mentions, has_combo_signal


def test_extract_mentions_finds_keywords():
    text = "Used MAC Spice liner with Velvet Teddy lipstick and Fenty Glow gloss"
    mentions = extract_mentions(text)
    keywords = [m["keyword"] for m in mentions]
    assert "liner" in keywords
    assert "lipstick" in keywords
    assert "gloss" in keywords


def test_extract_mentions_case_insensitive():
    text = "This BLUSH is amazing with the BRONZER"
    mentions = extract_mentions(text)
    assert len(mentions) == 2
    assert mentions[0]["keyword"] == "blush"
    assert mentions[1]["keyword"] == "bronzer"


def test_extract_mentions_empty_text():
    assert extract_mentions("") == []
    assert extract_mentions("No makeup keywords here") == []


def test_has_combo_signal():
    assert has_combo_signal("This lip combo is amazing")
    assert has_combo_signal("Liner paired with gloss")
    assert has_combo_signal("On the lips: MAC Spice + Velvet Teddy")
    assert not has_combo_signal("Just applied lipstick")
