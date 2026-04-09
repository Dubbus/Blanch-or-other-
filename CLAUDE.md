# Blanch

Beauty color analysis & product discovery iOS app. Users take a selfie, the app detects their skin undertone via on-device Core ML, and recommends makeup products + influencer lip combos matched to their color season.

## Project Origin

Conceived from a conversation with makeup influencer Sydney. See `/Users/muralihome/Documents/Adarsh/Professional Development/Project Notes/Sydney Makeup App Concepts.md` for the original concept notes.

## Tech Stack

### Backend (complete, running)
- **FastAPI** + **PostgreSQL** + **SQLAlchemy** (async, reuses Tirtham patterns)
- **Alembic** for migrations
- **Pydantic v2** schemas with camelCase aliasing (`CamelModel` base in `app/schemas/base.py`)
- Local PostgreSQL on port 5432, API on port 8001
- No Docker needed — uses local Postgres (`psql -U $(whoami) -d blanch`)

### iOS (Phase 1 complete, compiles clean)
- **SwiftUI** UI layer + **class-based OOP core** for all ViewModels, Repositories, Services, Networking
- **Swift 6.3** / Xcode 26.4
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
      ProductListViewModel.swift # Inherits BaseViewModel, uses optional Strategy
      Strategies/
        SeasonBasedStrategy.swift # Strategy pattern — products by color season
      Views/ProductListView.swift
    Influencers/
      InfluencerRepository.swift
      InfluencerListViewModel.swift
      Views/InfluencerListView.swift
```

### OOP Patterns in Use
| Pattern | Location | Purpose |
|---------|----------|---------|
| Builder | `RequestBuilder` | Fluent HTTP request construction |
| Template Method | `BaseViewModel.loadData()` → `fetchData()` | Shared loading/error flow |
| Singleton | `AuthManager.shared` | Global auth state |
| Factory | `ViewModelFactory` | Dependency injection for ViewModels |
| Repository | `ProductRepository`, `InfluencerRepository` | Abstract data source |
| Strategy | `SeasonBasedStrategy` (+ future Influencer, Popularity) | Swappable recommendation algorithms |
| Protocol | All `*Protocol` types | Testability, mock injection |
| Observer | `@Published` on ViewModels | SwiftUI reactive updates |
| Coordinator | `AppCoordinator` | Navigation logic outside views |
| Inheritance | Every ViewModel extends `BaseViewModel` | Shared loading state |
| Composition | AppCoordinator → ViewModelFactory → Repositories | Ownership hierarchy |

## Database

### Seeded Data
- **12** color seasons (4 categories × 3 variants, with hex palettes)
- **51** products (MAC, Fenty, Charlotte Tilbury, NYX, NARS, Rare Beauty, etc.)
- **12** influencers (Sydney Chambers, Mikayla Nogueira, Alix Earle, Patrick Ta, etc.)
- **24** lip combos with 68 combo items (liner + lipstick + gloss groupings)
- **153** auto-generated product-season mappings via CIE Delta-E color distance
- **32** influencer-season mappings

### Key Models
`User`, `ColorSeason`, `Product`, `ProductSeasonMap`, `Influencer`, `InfluencerSeasonMap`, `ProductMention`, `LipCombo`, `LipComboItem`, `UserAnalysisResult`, `UserSavedProduct`

## API Endpoints

All prefixed with `/api/v1/`:

- `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- `GET /seasons`, `GET /seasons/{id}`, `GET /seasons/{id}/products`, `GET /seasons/{id}/influencers`
- `GET /products`, `GET /products/search?q=`, `GET /products/{id}` (includes season mappings)
- `GET /influencers`, `GET /influencers/{id}`
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

# Run tests
python -m pytest tests/ -v

# iOS
cd ios/Blanch
xcodegen generate   # regenerate .xcodeproj from project.yml
open Blanch.xcodeproj
```

## Monetization
- **Free tier:** Basic color analysis result (primary season only), browse all products, search
- **Premium tier (subscription):** Full season breakdown with percentages, influencer matching, all lip combos per influencer
- **Affiliate links:** All product URLs can carry affiliate tracking params (field: `affiliate_url`)

## Design Decisions
- **App name:** Blanch (evokes skin tone / beauty)
- **Color palette:** warmBrown `#8B6355`, warmBeige `#F5E6D3`, warmIvory `#FFF8F0`, warmRose `#D4847C`, warmTerra `#C4967A`
- Backend reuses Tirtham patterns (FastAPI app factory, async SQLAlchemy, JWT auth, Alembic async env.py)
- Product lookup key is `(brand, shade_name, category)` to distinguish same-shade products (e.g., Charlotte Tilbury Pillow Talk liner vs lipstick)
- Color matching uses CIE76 Delta-E in LAB color space — top 3 season matches stored per product

## Current Status (Phase 1 complete)
- [x] Phase 0: Backend foundation (all models, endpoints, seed data, tests)
- [x] Phase 1: iOS skeleton + OOP architecture (24 files, clean compile)
- [ ] Phase 2: Core ML color analysis pipeline (camera → face detection → skin sampling → season)
- [ ] Phase 3: Product discovery + recommendations (Strategy pattern showcase)
- [ ] Phase 4: Influencer matching + lip combos
- [ ] Phase 5: Monetization + paywall (StoreKit 2)
- [ ] Phase 6: Polish + launch

## Next Steps
1. Download iOS 26 simulator runtime (`xcodebuild -downloadPlatform iOS`)
2. Build and run in simulator — verify product list + influencer list fetch from local API
3. Begin Phase 2: Core ML color analysis (AVCaptureSession → Vision face landmarks → skin pixel sampling → LAB → Delta-E → season)
