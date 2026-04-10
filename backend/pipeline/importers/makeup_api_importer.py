"""
Import products from the free Makeup API (makeup-api.herokuapp.com).

Fetches lip/blush/bronzer products, expands each shade into a separate
product row, converts prices to USD cents, and loads into the database.
Then runs color_matcher to auto-map season associations.
"""

import asyncio
import json
import math
import urllib.request
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.models.product import Product, ProductSeasonMap
from app.models.color_season import ColorSeason
from pipeline.parsers.color_matcher import match_color_to_seasons

API_URL = "http://makeup-api.herokuapp.com/api/v1/products.json"
SEEDS_DIR = Path(__file__).parent.parent / "seeds"

# Product types we care about, mapped to our category names
TYPE_MAP = {
    "lipstick": "lipstick",
    "lip_liner": "liner",
    "blush": "blush",
    "bronzer": "bronzer",
}

# Rough CAD/GBP → USD conversion for price normalization
CURRENCY_TO_USD = {
    "USD": 1.0,
    "CAD": 0.74,
    "GBP": 1.27,
}

# Brands to normalize to match our existing data
BRAND_NORMALIZE = {
    "nyx": "NYX",
    "clinique": "Clinique",
    "dior": "Dior",
    "covergirl": "CoverGirl",
    "maybelline": "Maybelline",
    "smashbox": "Smashbox",
    "l'oreal": "L'Oreal",
    "physicians formula": "Physicians Formula",
    "benefit": "Benefit",
    "revlon": "Revlon",
    "e.l.f.": "e.l.f.",
    "milani": "Milani",
    "almay": "Almay",
    "wet n wild": "Wet n Wild",
    "glossier": "Glossier",
    "fenty": "Fenty Beauty",
    "colourpop": "ColourPop",
    "stila": "Stila",
    "anna sui": "Anna Sui",
    "pacifica": "Pacifica",
    "marcelle": "Marcelle",
    "cargo cosmetics": "Cargo",
    "mineral fusion": "Mineral Fusion",
    "pure anada": "Pure Anada",
    "iman": "IMAN",
    "burt's bees": "Burt's Bees",
}


def fetch_products() -> list[dict]:
    """Fetch all products from the Makeup API."""
    print("Fetching products from Makeup API...")
    req = urllib.request.Request(API_URL, headers={"User-Agent": "Blanch/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())
    print(f"  Fetched {len(data)} total products")
    return data


def normalize_brand(brand: str) -> str:
    return BRAND_NORMALIZE.get(brand.lower().strip(), brand.title())


def parse_price_cents(price_str: str | None, currency: str | None) -> int | None:
    """Convert price string to USD cents."""
    if not price_str:
        return None
    try:
        price = float(price_str)
    except (ValueError, TypeError):
        return None
    if price <= 0:
        return None

    rate = CURRENCY_TO_USD.get(currency or "USD", 1.0)
    usd = price * rate
    return int(math.ceil(usd * 100))


def transform_products(raw: list[dict]) -> list[dict]:
    """
    Filter to relevant types and expand each shade into a product row.
    Returns list of dicts ready for DB insertion.
    """
    rows = []
    seen_keys = set()

    for p in raw:
        ptype = p.get("product_type", "")
        if ptype not in TYPE_MAP:
            continue

        colors = p.get("product_colors") or []
        if not colors:
            continue

        brand = normalize_brand(p.get("brand") or "Unknown")
        name = (p.get("name") or "").strip()
        category = TYPE_MAP[ptype]
        price_cents = parse_price_cents(p.get("price"), p.get("currency"))
        product_url = p.get("product_link") or p.get("website_link")
        image_url = p.get("api_featured_image") or p.get("image_link")

        # Clean up name — remove brand prefix if present
        if name.lower().startswith(brand.lower()):
            name = name[len(brand):].strip()
        # Remove leading dashes or spaces
        name = name.lstrip("- ").strip()
        if not name:
            name = category.title()

        for color in colors:
            hex_val = (color.get("hex_value") or "").strip()
            shade_name = (color.get("colour_name") or "").strip()

            if not hex_val.startswith("#") or len(hex_val) < 4:
                continue
            if not shade_name:
                shade_name = hex_val

            # Deduplicate by (brand, shade_name, category)
            key = (brand.lower(), shade_name.lower(), category)
            if key in seen_keys:
                continue
            seen_keys.add(key)

            rows.append({
                "brand": brand,
                "name": name,
                "category": category,
                "shade_name": shade_name,
                "hex_code": hex_val.upper(),
                "product_url": product_url,
                "image_url": image_url,
                "price_cents": price_cents,
                "retailer": "various",
            })

    return rows


async def load_products(db: AsyncSession, products: list[dict]) -> int:
    """Insert products into DB, skipping duplicates."""
    inserted = 0
    for row in products:
        existing = await db.execute(
            select(Product).where(
                Product.brand == row["brand"],
                Product.shade_name == row["shade_name"],
                Product.category == row["category"],
            )
        )
        if existing.scalar_one_or_none():
            continue

        db.add(Product(
            brand=row["brand"],
            name=row["name"],
            category=row["category"],
            shade_name=row["shade_name"],
            hex_code=row["hex_code"],
            product_url=row["product_url"],
            image_url=row["image_url"],
            price_cents=row["price_cents"],
            retailer=row["retailer"],
        ))
        inserted += 1

    await db.commit()
    return inserted


async def map_new_products_to_seasons(db: AsyncSession) -> int:
    """Run color matcher on all products that don't have season mappings yet."""
    seasons_data = json.loads((SEEDS_DIR / "color_seasons.json").read_text())

    # Get products without any season mappings
    result = await db.execute(
        select(Product).where(
            Product.hex_code.isnot(None),
            ~Product.id.in_(
                select(ProductSeasonMap.product_id).distinct()
            ),
        )
    )
    unmapped = result.scalars().all()
    print(f"  {len(unmapped)} products need season mapping")

    count = 0
    for product in unmapped:
        matches = match_color_to_seasons(product.hex_code, seasons_data)
        for match in matches[:3]:
            season = await db.execute(
                select(ColorSeason).where(ColorSeason.name == match["season_name"])
            )
            season_obj = season.scalar_one_or_none()
            if not season_obj or match["confidence"] < 0.1:
                continue
            db.add(ProductSeasonMap(
                product_id=product.id,
                season_id=season_obj.id,
                confidence=match["confidence"],
            ))
            count += 1

    await db.commit()
    return count


async def run():
    raw = fetch_products()
    products = transform_products(raw)
    print(f"  Transformed into {len(products)} shade rows")

    async with AsyncSessionLocal() as db:
        print("Loading into database...")
        inserted = await load_products(db, products)
        print(f"  Inserted {inserted} new products (skipped {len(products) - inserted} duplicates)")

        print("Mapping to color seasons...")
        mappings = await map_new_products_to_seasons(db)
        print(f"  Created {mappings} season mappings")

        # Final count
        total = await db.execute(select(Product))
        all_products = total.scalars().all()
        print(f"\nTotal products in database: {len(all_products)}")


if __name__ == "__main__":
    asyncio.run(run())
