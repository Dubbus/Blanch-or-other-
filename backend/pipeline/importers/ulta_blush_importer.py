"""Ulta Blush HEX Codes importer.

Reads the CSV exported from the spreadsheet and upserts products into the
database with explicit season mappings (confidence=1.0 since the season
assignment comes from human curation, not Delta-E estimation).

Usage:
    python -m pipeline.importers.ulta_blush_importer \
        --csv /path/to/Ulta\ Blush\ HEX\ Codes\ -\ Sheet1.csv

Idempotent: re-running is safe. Products are keyed on (brand, shade_name,
category); season maps use ON CONFLICT DO NOTHING.
"""

import argparse
import asyncio
import csv
import sys
import uuid
from pathlib import Path

from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.config import settings
from app.models.product import Product, ProductSeasonMap
from app.models.color_season import ColorSeason  # noqa: F401 — needed for relationship


# ── Season name mapping ────────────────────────────────────────────────────────
# CSV uses descriptive labels; DB uses canonical 12-season names.

SEASON_MAP = {
    "bright/clear spring":  "Bright Spring",
    "bright/clear winter":  "Bright Winter",
    "dark/deep autumn":     "Dark Autumn",
    "dark/deep winter":     "Deep Winter",
    "light spring":         "Light Spring",
    "light summer":         "Light Summer",
    "soft autumn":          "Soft Autumn",
    "soft summer":          "Soft Summer",
    "true/cool summer":     "True Summer",
    "true/cool winter":     "True Winter",
    "true/warm autumn":     "True Autumn",
    "true/warm spring":     "True Spring",
}


def canonical_season(raw: str) -> str | None:
    return SEASON_MAP.get(raw.strip().lower())


def derive_product_name(row: dict, url_to_name: dict[str, str]) -> str:
    """
    When the 'name' column is empty, try to recover the product name:
    1. From another row with the same URL that has a name.
    2. By stripping the shade prefix from 'swatch alt'.
    3. Fall back to 'swatch alt' verbatim.
    """
    name = row["name"].strip()
    if name:
        return name

    url = row["product url"].strip()
    if url in url_to_name:
        return url_to_name[url]

    # Strip shade prefix from swatch alt to recover product name.
    alt = row["swatch alt"].strip()
    shade = row["shade"].strip()
    if alt.lower().startswith(shade.lower()):
        derived = alt[len(shade):].strip()
        if derived:
            return derived

    return alt or shade


def build_url_to_name(rows: list[dict]) -> dict[str, str]:
    """Build a URL → product name index from rows that have a name."""
    result: dict[str, str] = {}
    for row in rows:
        url = row["product url"].strip()
        name = row["name"].strip()
        if name and url and url not in result:
            result[url] = name
    return result


async def load_season_ids(session: AsyncSession) -> dict[str, uuid.UUID]:
    result = await session.execute(select(ColorSeason.name, ColorSeason.id))
    return {name: id_ for name, id_ in result.all()}


async def import_csv(csv_path: Path) -> None:
    engine = create_async_engine(settings.database_url, echo=False)
    Session = async_sessionmaker(engine, expire_on_commit=False)

    with open(csv_path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    url_to_name = build_url_to_name(rows)

    async with Session() as session:
        season_ids = await load_season_ids(session)
        if not season_ids:
            print("ERROR: No seasons in DB. Run db_loader first.", file=sys.stderr)
            sys.exit(1)

        inserted = skipped = season_missing = 0

        for row in rows:
            brand      = row["brand"].strip()
            shade_name = row["shade"].strip()
            hex_code   = row["dominant color 1"].strip() or None
            swatch_url = row["swatch image url"].strip() or None
            product_url = row["product url"].strip() or None
            season_raw = row["Season Type"].strip()

            if not brand or not shade_name:
                skipped += 1
                continue

            name = derive_product_name(row, url_to_name)
            season_name = canonical_season(season_raw)

            if not season_name:
                print(f"  WARN: unknown season '{season_raw}' for {brand} — {shade_name}")
                season_missing += 1
                season_name = None

            # Upsert product — keyed on (brand, shade_name, category).
            stmt = pg_insert(Product).values(
                id=uuid.uuid4(),
                brand=brand,
                name=name,
                category="blush",
                shade_name=shade_name,
                hex_code=hex_code,
                swatch_url=swatch_url,
                product_url=product_url,
                retailer="ulta",
            ).on_conflict_do_update(
                index_elements=["brand", "shade_name", "category"],
                set_={
                    "name": name,
                    "hex_code": hex_code,
                    "swatch_url": swatch_url,
                    "product_url": product_url,
                    "retailer": "ulta",
                }
            ).returning(Product.id)

            result = await session.execute(stmt)
            product_id = result.scalar_one()

            # Season map — high confidence since assignment is human-curated.
            if season_name and season_name in season_ids:
                map_stmt = pg_insert(ProductSeasonMap).values(
                    product_id=product_id,
                    season_id=season_ids[season_name],
                    confidence=1.0,
                ).on_conflict_do_nothing()
                await session.execute(map_stmt)

            inserted += 1

        await session.commit()

    print(f"\nDone. {inserted} products upserted, {skipped} skipped, "
          f"{season_missing} unknown season labels.")
    await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Ulta blush products from CSV.")
    parser.add_argument(
        "--csv",
        required=True,
        type=Path,
        help="Path to 'Ulta Blush HEX Codes - Sheet1.csv'",
    )
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"ERROR: file not found: {args.csv}", file=sys.stderr)
        sys.exit(1)

    asyncio.run(import_csv(args.csv))


if __name__ == "__main__":
    main()
