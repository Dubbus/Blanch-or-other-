"""Tests for the CIE Delta-E color matching pipeline."""

import json
from pathlib import Path

from pipeline.parsers.color_matcher import (
    hex_to_rgb,
    hex_to_lab,
    delta_e,
    match_color_to_seasons,
)

SEEDS_DIR = Path(__file__).parent.parent / "pipeline" / "seeds"


def test_hex_to_rgb():
    assert hex_to_rgb("#FF0000") == (255, 0, 0)
    assert hex_to_rgb("#00FF00") == (0, 255, 0)
    assert hex_to_rgb("#000000") == (0, 0, 0)
    assert hex_to_rgb("#FFFFFF") == (255, 255, 255)


def test_hex_to_lab_produces_valid_ranges():
    l, a, b = hex_to_lab("#FF0000")
    assert 0 <= l <= 100
    # Red should have positive a* (red-green axis)
    assert a > 0


def test_delta_e_same_color_is_zero():
    lab = hex_to_lab("#FF0000")
    assert delta_e(lab, lab) == 0.0


def test_delta_e_different_colors_positive():
    lab1 = hex_to_lab("#FF0000")
    lab2 = hex_to_lab("#0000FF")
    assert delta_e(lab1, lab2) > 0


def test_match_color_to_seasons_returns_all_seasons():
    seasons = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    results = match_color_to_seasons("#A0522D", seasons)  # warm brown
    assert len(results) == 12
    assert all(0 <= r["confidence"] <= 1 for r in results)
    # Best match should have confidence 1.0
    assert results[0]["confidence"] == 1.0


def test_warm_brown_matches_autumn():
    """A warm brown like Velvet Teddy should best match autumn seasons."""
    seasons = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    results = match_color_to_seasons("#A0522D", seasons)
    top_3_names = [r["season_name"] for r in results[:3]]
    # At least one autumn season in top 3
    assert any("Autumn" in name for name in top_3_names)


def test_cool_red_matches_winter():
    """A cool true red should match winter seasons."""
    seasons = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    results = match_color_to_seasons("#CC0000", seasons)
    top_3_names = [r["season_name"] for r in results[:3]]
    assert any("Winter" in name for name in top_3_names)


def test_dusty_pink_matches_summer():
    """A muted dusty pink should match summer seasons."""
    seasons = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    results = match_color_to_seasons("#BC8F8F", seasons)
    top_3_names = [r["season_name"] for r in results[:3]]
    assert any("Summer" in name for name in top_3_names)
