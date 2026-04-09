"""
Database seed loader.

Loads seed JSON files into the database. Designed for idempotent runs —
uses upsert logic so it can be re-run safely.
"""

import asyncio
import json
import uuid
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.models.color_season import ColorSeason
from app.models.product import Product, ProductSeasonMap
from app.models.influencer import Influencer, InfluencerSeasonMap
from app.models.lip_combo import LipCombo, LipComboItem
from pipeline.parsers.color_matcher import match_color_to_seasons

SEEDS_DIR = Path(__file__).parent.parent / "seeds"


async def load_seasons(db: AsyncSession) -> dict[str, uuid.UUID]:
    """Load color seasons from seed file. Returns name -> id mapping."""
    data = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    name_to_id = {}

    for season_data in data:
        result = await db.execute(
            select(ColorSeason).where(ColorSeason.name == season_data["name"])
        )
        existing = result.scalar_one_or_none()

        if existing:
            existing.undertone = season_data["undertone"]
            existing.category = season_data["category"]
            existing.description = season_data["description"]
            existing.hex_palette = season_data["hex_palette"]
            name_to_id[existing.name] = existing.id
        else:
            season = ColorSeason(
                name=season_data["name"],
                undertone=season_data["undertone"],
                category=season_data["category"],
                description=season_data["description"],
                hex_palette=season_data["hex_palette"],
            )
            db.add(season)
            await db.flush()
            name_to_id[season.name] = season.id

    await db.commit()
    print(f"Loaded {len(name_to_id)} color seasons")
    return name_to_id


async def load_products(db: AsyncSession) -> dict[tuple[str, str], uuid.UUID]:
    """Load products from seed file. Returns (brand, shade_name) -> id mapping."""
    data = json.loads((SEEDS_DIR / "products.json").read_text())
    product_map = {}

    for p_data in data:
        key = (p_data["brand"], p_data.get("shade_name", p_data["name"]), p_data["category"])
        result = await db.execute(
            select(Product).where(
                Product.brand == p_data["brand"],
                Product.shade_name == p_data.get("shade_name"),
                Product.name == p_data["name"],
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            for field in ["category", "hex_code", "retailer", "price_cents", "product_url"]:
                if field in p_data:
                    setattr(existing, field, p_data[field])
            product_map[key] = existing.id
        else:
            product = Product(
                brand=p_data["brand"],
                name=p_data["name"],
                category=p_data["category"],
                shade_name=p_data.get("shade_name"),
                hex_code=p_data.get("hex_code"),
                retailer=p_data.get("retailer"),
                price_cents=p_data.get("price_cents"),
                product_url=p_data.get("product_url"),
                swatch_url=p_data.get("swatch_url"),
                image_url=p_data.get("image_url"),
            )
            db.add(product)
            await db.flush()
            product_map[key] = product.id

    await db.commit()
    print(f"Loaded {len(product_map)} products")
    return product_map


async def map_products_to_seasons(
    db: AsyncSession,
    season_name_to_id: dict[str, uuid.UUID],
) -> int:
    """Auto-map products to seasons using CIE Delta-E color matching."""
    seasons_data = json.loads((SEEDS_DIR / "color_seasons.json").read_text())
    result = await db.execute(select(Product).where(Product.hex_code.isnot(None)))
    products = result.scalars().all()
    count = 0

    for product in products:
        matches = match_color_to_seasons(product.hex_code, seasons_data)
        # Store top 3 season matches
        for match in matches[:3]:
            season_id = season_name_to_id.get(match["season_name"])
            if not season_id or match["confidence"] < 0.1:
                continue

            existing = await db.execute(
                select(ProductSeasonMap).where(
                    ProductSeasonMap.product_id == product.id,
                    ProductSeasonMap.season_id == season_id,
                )
            )
            if not existing.scalar_one_or_none():
                db.add(ProductSeasonMap(
                    product_id=product.id,
                    season_id=season_id,
                    confidence=match["confidence"],
                ))
                count += 1

    await db.commit()
    print(f"Created {count} product-season mappings")
    return count


async def load_influencers(
    db: AsyncSession,
    season_name_to_id: dict[str, uuid.UUID],
) -> dict[str, uuid.UUID]:
    """Load influencers from seed file. Returns handle -> id mapping."""
    data = json.loads((SEEDS_DIR / "influencers.json").read_text())
    handle_to_id = {}

    for inf_data in data:
        result = await db.execute(
            select(Influencer).where(Influencer.handle == inf_data["handle"])
        )
        existing = result.scalar_one_or_none()
        primary_season_id = season_name_to_id.get(inf_data.get("primary_season"))

        if existing:
            existing.display_name = inf_data.get("display_name")
            existing.follower_count = inf_data.get("follower_count")
            existing.bio = inf_data.get("bio")
            existing.instagram_url = inf_data.get("instagram_url")
            existing.tiktok_url = inf_data.get("tiktok_url")
            existing.primary_season_id = primary_season_id
            handle_to_id[existing.handle] = existing.id
        else:
            influencer = Influencer(
                handle=inf_data["handle"],
                platform=inf_data["platform"],
                display_name=inf_data.get("display_name"),
                follower_count=inf_data.get("follower_count"),
                bio=inf_data.get("bio"),
                instagram_url=inf_data.get("instagram_url"),
                tiktok_url=inf_data.get("tiktok_url"),
                primary_season_id=primary_season_id,
            )
            db.add(influencer)
            await db.flush()
            handle_to_id[influencer.handle] = influencer.id

        # Map influencer to seasons
        for season_name in inf_data.get("matched_seasons", []):
            season_id = season_name_to_id.get(season_name)
            if not season_id:
                continue
            inf_id = handle_to_id[inf_data["handle"]]
            existing_map = await db.execute(
                select(InfluencerSeasonMap).where(
                    InfluencerSeasonMap.influencer_id == inf_id,
                    InfluencerSeasonMap.season_id == season_id,
                )
            )
            if not existing_map.scalar_one_or_none():
                db.add(InfluencerSeasonMap(
                    influencer_id=inf_id,
                    season_id=season_id,
                ))

    await db.commit()
    print(f"Loaded {len(handle_to_id)} influencers")
    return handle_to_id


async def load_lip_combos(
    db: AsyncSession,
    handle_to_id: dict[str, uuid.UUID],
    product_map: dict[tuple[str, str], uuid.UUID],
) -> int:
    """Load lip combos from seed file."""
    data = json.loads((SEEDS_DIR / "lip_combos.json").read_text())
    count = 0

    for combo_data in data:
        influencer_id = handle_to_id.get(combo_data["influencer_handle"])
        if not influencer_id:
            print(f"  WARNING: Influencer {combo_data['influencer_handle']} not found, skipping combo")
            continue

        # Check if combo already exists
        result = await db.execute(
            select(LipCombo).where(
                LipCombo.influencer_id == influencer_id,
                LipCombo.name == combo_data["name"],
            )
        )
        if result.scalar_one_or_none():
            continue

        combo = LipCombo(
            influencer_id=influencer_id,
            name=combo_data["name"],
        )
        db.add(combo)
        await db.flush()

        for i, item_data in enumerate(combo_data["items"]):
            product_key = (item_data["brand"], item_data["shade_name"], item_data["category"])
            product_id = product_map.get(product_key)
            if not product_id:
                print(f"  WARNING: Product {product_key} not found, skipping combo item")
                continue

            db.add(LipComboItem(
                combo_id=combo.id,
                product_id=product_id,
                role=item_data["role"],
                sort_order=i,
            ))

        count += 1

    await db.commit()
    print(f"Loaded {count} lip combos")
    return count


async def seed_all():
    """Run all seed loaders in order."""
    async with AsyncSessionLocal() as db:
        print("=== Seeding Blanch Database ===\n")

        print("Step 1: Loading color seasons...")
        season_map = await load_seasons(db)

        print("Step 2: Loading products...")
        product_map = await load_products(db)

        print("Step 3: Mapping products to seasons (Delta-E)...")
        await map_products_to_seasons(db, season_map)

        print("Step 4: Loading influencers...")
        handle_map = await load_influencers(db, season_map)

        print("Step 5: Loading lip combos...")
        await load_lip_combos(db, handle_map, product_map)

        print("\n=== Seeding Complete ===")


if __name__ == "__main__":
    asyncio.run(seed_all())
