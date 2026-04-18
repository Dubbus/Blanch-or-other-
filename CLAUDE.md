# Blanch

Beauty color analysis & product discovery iOS app. Users take a selfie, the app detects their skin undertone via on-device Core ML, and recommends makeup products + influencer lip combos matched to their color season.

## Project Origin

Conceived from a conversation with makeup influencer Sydney. See `/Users/muralihome/Documents/Adarsh/Professional Development/Project Notes/Sydney Makeup App Concepts.md` for the original concept notes.

## Tech Stack
"Do not echo full file contents after writes, only confirm the path and line count." This alone cuts a huge amount of tool output tokens.

### Backend (complete, running)
- **FastAPI** + **PostgreSQL** + **SQLAlchemy** (async, reuses Tirtham patterns)
- **Alembic** for migrations
- **Pydantic v2** schemas with camelCase aliasing (`CamelModel` base in `app/schemas/base.py`)
- Local PostgreSQL on port 5432, API on port 8001
- No Docker needed — uses local Postgres (`psql -U $(whoami) -d blanch`)

### iOS (Phase 2 in progress — analysis pipeline functional, compiles clean)
- **SwiftUI** UI layer + **class-based OOP core** for all ViewModels, Repositories, Services, Networking
- **Swift 6.0** / Xcode 26.4 with **strict concurrency** (`SWIFT_STRICT_CONCURRENCY: complete`)
- Deployment target: iOS 18.0
- Project generated via **XcodeGen** (`project.yml` → `xcodegen generate`)
- Warm organic design aesthetic (Rare Beauty inspired — soft gradients, rounded shapes, earth tones)

## Architecture

### Backend Structure
```
backend/
  app/
    main.py              # FastAPI app factory, 7 routers
    config.py            # pydantic-settings, reads .env
    database.py          # async SQLAlchemy engine + Base
    deps.py              # get_current_user, require_premium (JWT + subscription gating)
    models/              # 11 SQLAlchemy models
    schemas/             # Pydantic DTOs with CamelModel base
    services/            # Business logic (auth, products, seasons, influencers, combos, analysis)
    routers/             # REST endpoints (auth, seasons, products, influencers, combos, analysis, subscriptions)
  migrations/            # Alembic (async env.py pattern from Tirtham)
  pipeline/
    seeds/               # JSON seed data (color_seasons, products, influencers, lip_combos)
    parsers/             # color_matcher.py (CIE Delta-E), mention_extractor.py, combo_detector.py
    loaders/db_loader.py # Idempotent seed loader (python -m pipeline.loaders.db_loader)
    importers/
      makeup_api_importer.py  # Bulk import from free Makeup API (python -m pipeline.importers.makeup_api_importer)
    scrapers/            # Instagram scraper scaffold (not yet implemented)
  tests/                 # pytest (color_matcher + mention_extractor tests)
```

### iOS Structure (OOP Pattern Map)
```
ios/Blanch/Blanch/
  App/
    BlanchApp.swift              # @main entry point
    AppCoordinator.swift         # Coordinator pattern — owns navigation + child coordinators
  Core/
    Protocols/
      RepositoryProtocol.swift   # Protocol pattern — abstracts data source for testing
      RecommendationStrategy.swift # Strategy pattern — swappable recommendation algorithms
    Base/
      BaseViewModel.swift        # Template Method — loadData() skeleton, subclasses override fetchData()
    Networking/
      NetworkClient.swift        # Concrete HTTP client (owns URLSession)
      NetworkClientProtocol.swift # Protocol for mock injection
      RequestBuilder.swift       # Builder pattern — fluent API for URLRequest construction
      Endpoints.swift            # API path constants
    Auth/
      AuthManager.swift          # Singleton pattern — @MainActor, one auth session app-wide
  Domain/DTOs/                   # Codable structs matching API JSON exactly
  Factory/
    ViewModelFactory.swift       # Factory pattern — creates ViewModels with dependencies injected
  Features/
    Products/
      ProductRepository.swift    # Repository pattern — concrete API implementation
      ProductListViewModel.swift # Inherits BaseViewModel, uses optional Strategy, brand/category filters
      ProductDetailViewModel.swift # Loads product with seasons + sibling shades
      Strategies/
        SeasonBasedStrategy.swift # Strategy pattern — products by color season
      Views/
        ProductListView.swift    # Discover tab: search, category pills, brand pills, product grid
        ProductDetailView.swift  # Sephora-style detail: hero swatch, shade picker, season match, retailer link
    Analysis/
      AnalysisRepository.swift     # Repository — submits analysis to backend, resolves season name→UUID via actor cache
      AnalysisViewModel.swift      # Inherits BaseViewModel — orchestrates analyze→result→submit flow
      Views/
        AnalysisView.swift         # Analyze tab: start (guidelines) → analyzing → result → submitted states
    Influencers/
      InfluencerRepository.swift
      InfluencerListViewModel.swift
      Views/
        InfluencerListView.swift
        InfluencerDetailView.swift  # Profile with Instagram/TikTok social link buttons
```

### Analysis Pipeline Architecture
```
ios/Blanch/Blanch/Core/Analysis/
  AnalysisPipeline.swift           # Template Method — orchestrates: palettes → face detect → skin sample → classify
  FaceDetector.swift               # Wraps Vision VNDetectFaceRectanglesRequest, returns face bbox
  SkinSampler.swift                # Samples forehead + cheek pixels from face bbox, filters skin, averages LAB
  SeasonClassificationStrategy.swift # Strategy pattern — SkinToneAxisStrategy scores 12 seasons by undertone/value/chroma
  SeasonPaletteProviding.swift     # Loads bundled SeasonPalettes.json (12 seasons with hex palettes)
  ColorSpaceConverter.swift        # RGB↔LAB conversion, CIE76 Delta-E
```

Pipeline flow: `UIImage → normalize orientation → CGImage → Vision face detect → skin sample (3 regions) → LAB average → score 12 seasons → AnalysisOutcome`

### Analysis Pipeline Design Decisions
- **Photo picker (PHPicker)** over live camera for v1 — simpler, user can pick well-lit photo
- **Season palettes bundled locally** as JSON — enables offline analysis; backend UUIDs resolved at submission time via GET /seasons (cached in actor)
- **VNDetectFaceRectanglesRequest** (not Landmarks) — Landmarks requires Neural Engine which fails on iOS Simulator ("could not create inference context"). Pinned to revision 1.
- **CGImage passed to Vision** (not CIImage) — more reliable on simulator
- **Skin sampling: 3 regions** (forehead, left cheek, right cheek) — jawline dropped because it picks up beard stubble and neck shadow
- **Forehead region shifted lower** (y 0.18 vs 0.12) to avoid hairline clipping
- **Brightness floor 0.25** (was 0.12) to reject stubble/shadow
- **Red-green spread filter** (r-g > 0.04) to reject near-grey shadow/background pixels
- **Classifier weights**: undertone (b*) 0.40, value (L*) 0.40, chroma 0.20 — equal undertone/value prevents fair warm-toned subjects from being pulled toward Deep/True variants
- **No hair/eye sampling yet** — real analysts lean on hair color heavily for variant disambiguation (Light vs Soft vs Deep within a season family)
- **CheckedContinuation safety**: Vision's perform() is synchronous and can fire the completion handler during the call. Result captured in local `Result?` and continuation resumed exactly once after perform returns.

### Known Pipeline Limitations (v1)
- Skin-only classification — no hair or eye color signal, so variant ranking (Light/Soft/Deep) within a season family is weaker than the family call itself
- No white balance normalization — colored ambient light shifts b* (undertone axis) directly
- Mean averaging — outlier pixels (freckles, shadow edges) drag the average; median would be more robust
- No exposure normalization — under/overexposed photos bias L* (value axis)
- Lighting guidelines shown to user but not enforced programmatically

### OOP Patterns in Use
| Pattern | Location | Purpose |
|---------|----------|---------|
| Builder | `RequestBuilder` | Fluent HTTP request construction |
| Template Method | `BaseViewModel.loadData()` → `fetchData()` | Shared loading/error flow |
| Singleton | `AuthManager.shared` | Global auth state |
| Factory | `ViewModelFactory` | Dependency injection for ViewModels |
| Repository | `ProductRepository`, `InfluencerRepository`, `AnalysisRepository` | Abstract data source |
| Strategy | `SeasonBasedStrategy`, `SkinToneAxisStrategy` | Swappable recommendation & classification algorithms |
| Protocol | All `*Protocol` types | Testability, mock injection |
| Observer | `@Published` on ViewModels | SwiftUI reactive updates |
| Coordinator | `AppCoordinator` | Navigation logic outside views |
| Inheritance | Every ViewModel extends `BaseViewModel` | Shared loading state |
| Composition | AppCoordinator → ViewModelFactory → Repositories | Ownership hierarchy |

## Database

### Product Data
- **2,326** products across **48 brands** (1,610 lipstick, 292 liner, 268 blush, 144 bronzer, 9 gloss, 3 tint)
- **51** hand-curated seed products (MAC, Fenty, Charlotte Tilbury, NYX, NARS, Rare Beauty, Patrick Ta, etc.)
- **2,275** bulk-imported from Makeup API (NYX, Clinique, Dior, Maybelline, Smashbox, ColourPop, etc.)
- **~7,000** auto-generated product-season mappings via CIE Delta-E color distance

### Influencer & Combo Data
- **12** color seasons (4 categories × 3 variants, with hex palettes)
- **12** influencers with Instagram/TikTok URLs (Sydney Chambers, Mikayla Nogueira, Alix Earle, Patrick Ta, etc.)
- **24** lip combos with 68 combo items (liner + lipstick + gloss groupings)
- **32** influencer-season mappings

### Key Models
`User`, `ColorSeason`, `Product`, `ProductSeasonMap`, `Influencer`, `InfluencerSeasonMap`, `ProductMention`, `LipCombo`, `LipComboItem`, `UserAnalysisResult`, `UserSavedProduct`

## API Endpoints

All prefixed with `/api/v1/`:

- `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- `GET /seasons`, `GET /seasons/{id}`, `GET /seasons/{id}/products`, `GET /seasons/{id}/influencers`
- `GET /products/brands` — list all distinct brands
- `GET /products` (filters: `category`, `brand`, `retailer`, `season_id`; pagination: `limit`, `offset`)
- `GET /products/search?q=`
- `GET /products/{id}` — includes season mappings with confidence
- `GET /products/{id}/shades` — sibling shade variants for swatch picker
- `GET /influencers` (filters: `season_id`, `platform`), `GET /influencers/{id}`
- `GET /combos/influencer/{id}` (PREMIUM), `GET /combos/{id}`
- `POST /analysis`, `GET /analysis/me` (free), `GET /analysis/me/full` (PREMIUM)
- `POST /subscriptions/verify`, `GET /subscriptions/status`

## Running Locally

```bash
# Backend
cd backend
source .venv/bin/activate
uvicorn app.main:app --port 8001 --reload

# Reseed database
python -m pipeline.loaders.db_loader

# Bulk import products from Makeup API
python -m pipeline.importers.makeup_api_importer

# Run tests
python -m pytest tests/ -v

# iOS
cd ios/Blanch
xcodegen generate   # regenerate .xcodeproj from project.yml
open Blanch.xcodeproj

# Build & run in simulator
xcodebuild -project Blanch.xcodeproj -scheme Blanch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build_output build
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl install "iPhone 17 Pro" build_output/Build/Products/Debug-iphonesimulator/Blanch.app
xcrun simctl launch "iPhone 17 Pro" com.blanch.app
open -a Simulator
```

## Monetization
- **Free tier:** Basic color analysis result (primary season only), browse all products, search
- **Premium tier (subscription):** Full season breakdown with percentages, influencer matching, all lip combos per influencer
- **Affiliate links:** All product URLs can carry affiliate tracking params (field: `affiliate_url`)

## Design Decisions
- **App name:** Blanch (evokes skin tone / beauty)
- **Color palette:** warmBrown `#8B6355`, warmBeige `#F5E6D3`, warmIvory `#FFF8F0`, warmRose `#D4847C`, warmTerra `#C4967A`
- Backend reuses Tirtham patterns (FastAPI app factory, async SQLAlchemy, JWT auth, Alembic async env.py)
- Product lookup key is `(brand, shade_name, category)` to distinguish same-shade products
- Color matching uses CIE76 Delta-E in LAB color space — top 3 season matches stored per product
- All protocols and concrete classes conform to `Sendable` for Swift 6 strict concurrency
- Discover tab has two filter rows (category + brand) that combine, with item count

## Current Status
- [x] Phase 0: Backend foundation (all models, endpoints, seed data, tests)
- [x] Phase 1: iOS skeleton + OOP architecture (26 files, clean compile)
- [x] Phase 1.5: Swift 6 strict concurrency fixes (Sendable conformance on all protocols/classes)
- [x] Phase 1.6: Influencer detail view with Instagram/TikTok social links
- [x] Phase 1.7: Discover tab rework (brand + category filters, Sephora-style product detail with swatch picker + season match bars, "Find your shades" banner)
- [x] Phase 1.8: Bulk product import via Makeup API (51 → 2,326 products, 48 brands, auto season mapping)
- [x] Phase 2: Color analysis pipeline — photo picker → Vision face detection → skin sampling → LAB → season classification → submit to backend (functional, tuning in progress)
- [ ] Phase 2.5: Pipeline accuracy improvements — hair/eye sampling, white balance normalization, median averaging, exposure normalization
- [ ] Phase 3: Product discovery + recommendations (activate "Recommended for You" + match badges)
- [ ] Phase 4: Influencer matching + lip combos
- [ ] Phase 5: Monetization + paywall (StoreKit 2)
- [ ] Phase 6: Polish + launch

## Next Steps
1. Phase 2.5: Pipeline accuracy improvements
   - Sample hair color above face bbox + eye region for variant disambiguation
   - White balance normalization using neutral reference (sclera or brightest non-skin pixel)
   - Median-based averaging instead of mean (robust to freckles, shadow outliers)
   - Exposure normalization to decouple L* from camera metering
2. Wire season result into Discover tab (activate "Recommended for You" section + match badges on products)
3. Build influencer lip combo browsing (Phase 4)

## Future Goals (Backlog)
- Custom Sephora/Ulta product scraper for premium brand data with accurate hex codes (scaffold at `pipeline/scrapers/`)
- Community lip combo submissions — let users submit combos for their color season (design decision pending: free community data vs premium personalized matching layer)
- Spreadsheet import pipeline for external color analysis data (TikTok creator's spreadsheet with product URLs, shades, hex codes)
- Instagram/TikTok caption scraping via Apify for influencer product mentions and lip combo detection
- Discover tab enhancements: shade match percentage indicator on product cards when user has season result
