# Blanch

Beauty color analysis & product discovery iOS app. Users go through a two-stage draping quiz (factual questions + A/B lip renders on their own selfie), land on a color season with an explainer, and get matched makeup products + influencer lip combos.

## Project Origin

Conceived from a conversation with makeup influencer Sydney. See `/Users/muralihome/Documents/Adarsh/Professional Development/Project Notes/Sydney Makeup App Concepts.md` for the original concept notes.

### Pivot — pure CV → hybrid quiz + draping (2026-04)
Sydney's follow-up feedback flagged two problems with the pure-CV analysis pipeline: (1) lighting variables make selfies unreliable (even outdoor sun photos trend warm), and (2) users find "which shade pops?" questions obtuse. Response: keep the CV pipeline as a silent prior, but drive the result through a **two-stage questionnaire** that differentiates Blanch from competitors like Colorwise.me.

Key differentiation vs. Colorwise:
- **Product-first output** — we output actual shoppable lipsticks (2,326 products), not just a palette.
- **Negative selection** — Stage 2 asks "which makes you look tired?" instead of "which do you like?" — faster and more confident.
- **Lip draping on the user's own face** — Colorwise drapes fabric; we render lipstick onto the user's lips via Vision.
- **Makeup-artist factual questions** — vein color, jewelry, sun, whites — things a color picker can't capture.
- **Bayesian narrowing** — adaptive quiz length based on posterior confidence, not fixed steps.

## Tech Stack
"Do not echo full file contents after writes, only confirm the path and line count." This alone cuts a huge amount of tool output tokens.

### Backend (complete, running)
- **FastAPI** + **PostgreSQL** + **SQLAlchemy** (async, reuses Tirtham patterns)
- **Alembic** for migrations
- **Pydantic v2** schemas with camelCase aliasing (`CamelModel` base in `app/schemas/base.py`)
- Local PostgreSQL on port 5432, API on port 8001
- No Docker needed — uses local Postgres (`psql -U $(whoami) -d blanch`)

### iOS (Phase 2 complete — two-stage quiz shipped; Stage 3 tiebreaker in progress)
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
    Session/
      UserSession.swift          # Persisted user color season (UserDefaults-backed)
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
    Auth/
      AuthRepository.swift          # Repository — POST /auth/register, POST /auth/login
      AuthViewModel.swift           # Toggle login/register, client-side validation
      Views/
        SignInView.swift            # Combined sign-in/register form with mode toggle
        ProfileView.swift           # Logged-in profile + current season card + logout
    Questionnaire/
      Model/
        QuizQuestion.swift          # Stage 1 types (QuizQuestion, QuizAnswer, AnswerLikelihood)
        Stage1Questions.swift       # 4 factual questions (veins, jewelry, sun, whites)
        SharedPosterior.swift       # Reference-type state shared across Stage 1 + Stage 2
        DrapingShade.swift          # 8-shade Stage 2 catalog (hex + season likelihood)
      Scoring/
        QuestionnaireScorer.swift   # Strategy — BayesianSeasonScorer applies multiplicative likelihoods
        ResultExplainer.swift       # Translates picks into 'Why this season?' narration + axis bars
      Stage2/
        LipRegionDetector.swift     # Vision landmarks + heuristic ellipse fallback for simulator
        LipRenderer.swift           # CoreImage pipeline: mask + multiply blend onto lip polygon
        DrapingPairSelector.swift   # Information-gain pair picker + Stage 3 tiebreaker builder
        DrapingViewModel.swift      # Flow state machine (idle→processing→pairing→tiebreaker→finished)
        Views/
          DrapingCaptureView.swift  # PHPicker entry point with draping explainer
          DrapingProcessingView.swift
          DrapingPairView.swift     # A/B forced-choice on user's lip-rendered selfie
      QuestionnaireViewModel.swift  # Stage 1 ViewModel — writes through SharedPosterior
      Views/
        QuestionnaireHostView.swift # Stage router (stage1 → stage1Result → stage2 → finalResult)
        QuestionnaireResultView.swift # Stage 1 interstitial ("preliminary read" + continue)
        FinalResultView.swift       # Combined result: top season, save, why-card, breakdown
```

### Quiz Architecture (primary color-analysis flow)

Two-stage Bayesian quiz that outputs a posterior over 12 color seasons. Stage 1 runs offline from bundled palettes; Stage 2 requires a user selfie but does its rendering on-device with Vision + CoreImage. Stage 3 tiebreaker is in progress.

**Flow:**
```
Stage 1: 4 factual questions → posterior over 12 seasons (uniform prior + multiplicative likelihoods)
  ↓
Preliminary result (QuestionnaireResultView — framed as "rough family call")
  ↓
Stage 2: PHPicker selfie → Vision lip region → render 8 shades → 4 A/B pairs (negative-framed)
         Pair selector picks pairs that maximize information gain between top seasons.
  ↓
Stage 3: one final A/B between shades representing top vs runner-up seasons (positive-framed, 2× weight) [IN PROGRESS]
  ↓
FinalResultView: top season + confidence, "Why this season?" narration, save→backend, shareable
  ↓
UserSession persists season → Discover tab "Recommended for You" activates
```

**Data model:**
- `AnswerLikelihood` — 4 multiplicative axis weights: `undertoneWarm`, `undertoneCool`, `depthLight`, `depthDeep`. `1.0` = neutral, `>1` favors, `<1` penalizes.
- `SharedPosterior` — `@MainActor ObservableObject` holding the running `[String: Double]` posterior + loaded palettes. Passed into both `QuestionnaireViewModel` (Stage 1) and `DrapingViewModel` (Stage 2) so answers compound.
- `BayesianSeasonScorer` — for each palette, multiplies prior by `undertoneMatch × depthMatch`, then renormalizes. Depth mapping: spring→light, winter→deep, summer/autumn→half-weight blend.
- `ResultExplainer` — walks picks, computes log-space axis scores (squashed with `tanh`), emits up to 5 prioritized reasons with icons.

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

### Quiz Design Decisions
- **Stage 1 weights intentionally mild (0.5–1.9)** — no single answer can lock the user into the wrong family. Confidence after Stage 1 alone caps around 25-45% by design; Stage 2 does the heavy lifting.
- **Stage 2 weights stronger (1.55–1.9)** — each A/B pair on the user's own face carries more signal than abstract factual questions.
- **Negative framing on Stage 2** — "which makes you look tired?" (not "which looks best?"). Psych research: people are faster and more confident on negative identification. The ViewModel applies the WINNER's likelihood (the shade user did NOT pick).
- **Stage 3 flips to positive framing** — "which feels more like you?" — the final tiebreaker rewards a deliberate positive pick, with 2× weight to decisively resolve top-vs-runner-up.
- **Prompt rotation** — 6 negative-framed prompts rotate across Stage 2 pairs so the quiz doesn't feel repetitive.
- **Information-gain pair selection** — `DrapingPairSelector` scores every shade pair by L1 distance between the two posteriors that would result from each shade winning. Greedy top-N with a no-repeat-shade rule to vary the UI.
- **Tiebreaker builder** — picks the shade that most boosts the top season and the shade that most boosts the runner-up, ensuring the Stage 3 A/B is literally "which season are you?"
- **Pre-render all shades up front** — Stage 2 renders all 8 catalog shades onto the selfie during `processing` phase so pair transitions are instant (no per-tap latency).
- **Vision landmarks with heuristic fallback** — `VNDetectFaceLandmarksRequest` for outer-lip polygon on device; ellipse at `(midX, minY + 0.80 × height)` with `rx = 0.175 × width, ry = 0.045 × height` as simulator fallback. Sim is known-misaligned (lips drift to forehead); device will use real landmarks.
- **CoreImage pipeline** — rasterize polygon → grayscale mask → gaussian blur for feathered edges → multiply-blend tinted layer over source via `CIBlendWithMask`. Preserves lip texture under the tint.
- **Orientation normalization before Vision** — EXIF-rotated iPhone photos must be baked to `.up` before `VNImageRequestHandler` with `orientation: .up`, otherwise Vision detects a sideways face and the lip render lands on the forehead. Same `normalizedToUp()` helper as `AnalysisPipeline`.
- **Shared posterior via reference type** — `SharedPosterior: ObservableObject` holds the cross-stage state. Simpler than threading `@Binding` through VM boundaries.
- **Explainer uses log-space axis scores** — per-answer `log(warm/cool)` and `log(deep/light)` summed, then `tanh`-squashed to [-1, +1] for the UI bars. Keeps bars visually stable when one axis dominates.
- **Stage 2 submit requires auth** — `POST /analysis` requires JWT; Profile tab gates sign-in/register before Save works. `UserSession` persists the result to UserDefaults so Discover tab can personalize even across launches.

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

### Known Quiz Limitations (v1)
- Confidence ceiling feels low (~25-45% after Stage 1, ~50-70% after Stage 2) — tuning pass pending
- Lip render misaligned on simulator due to sim-incompatible `VNDetectFaceLandmarksRequest` — real device should be accurate
- Shade catalog is hardcoded 8 shades — no backend product integration yet (Phase 3 wiring)
- No retake-selfie mid-flow; full restart required
- No Stage 1 questions for eye color, hair color, freckles, or flush — these are the highest-info additions queued up

### OOP Patterns in Use
| Pattern | Location | Purpose |
|---------|----------|---------|
| Builder | `RequestBuilder` | Fluent HTTP request construction |
| Template Method | `BaseViewModel.loadData()` → `fetchData()` | Shared loading/error flow |
| Singleton | `AuthManager.shared` | Global auth state |
| Factory | `ViewModelFactory` | Dependency injection for ViewModels |
| Repository | `ProductRepository`, `InfluencerRepository`, `AnalysisRepository`, `AuthRepository` | Abstract data source |
| Strategy | `SeasonBasedStrategy`, `SkinToneAxisStrategy`, `BayesianSeasonScorer`, `InformationGainPairSelector`, `TopSeasonTiebreakerBuilder`, `ResultExplainer` | Swappable algorithms |
| State Machine | `DrapingViewModel.Phase` | idle→processing→pairing→tiebreaker→finished |
| Shared Reference State | `SharedPosterior`, `UserSession` | Cross-VM/cross-tab state with Combine observation |
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
- [x] Phase 2: Color analysis pipeline — photo picker → Vision face detection → skin sampling → LAB → season classification → submit to backend (functional, retained as silent prior)
- [x] Phase 2.6: Quiz Stage 1 — 4 factual questions (veins, jewelry, sun, whites) + Bayesian scorer + preliminary result view
- [x] Phase 2.7: Quiz Stage 2 — lip draping with Vision landmarks, heuristic sim fallback, CoreImage pipeline, 8-shade catalog, information-gain pair selector, negative-framed A/B UI, backend submit via `submitQuizResult`, Discover tab "Recommended for You" wired to `UserSession`
- [x] Phase 2.8: Auth flow — sign-in/register SignInView + ProfileView, unblocks `POST /analysis` submission
- [x] Phase 2.9: Result explainer — "Why this season?" card with axis bars + bulleted reasons
- [ ] **Phase 3.0 (IN PROGRESS): Stage 3 tiebreaker** — final A/B between top vs runner-up, 2× weight, positive-framed
- [ ] Phase 3.1: Weight calibration + extensive end-to-end testing (user deferred until after build-out)
- [ ] Phase 3.2: Additional Stage 1 questions (eye color, natural hair color, freckles, flush) — highest-info-gain additions
- [ ] Phase 3.3: UX polish (retake selfie mid-flow, adaptive pair count, sharing)
- [ ] Phase 3.4: Pipeline accuracy improvements (hair/eye sampling, white balance, median, exposure)
- [ ] Phase 4: Influencer matching + lip combos — activate combo cards using user's saved season
- [ ] Phase 5: Monetization + paywall (StoreKit 2)
- [ ] Phase 6: Polish + launch

## Step-by-Step Plan (current working list)

1. **Finish Stage 3 tiebreaker** (in progress)
   - [x] `DrapingPair.isTiebreaker` flag + `TopSeasonTiebreakerBuilder`
   - [x] `.tiebreaker` phase in `DrapingViewModel.Phase`
   - [x] `moveToTiebreakerOrFinish()` transition + 2× weight on pick
   - [x] `currentPair` / `currentIndex` / `totalPairCount` updated to include tiebreaker
   - [ ] `DrapingPairView` "Final call" badge when `pair.isTiebreaker`
   - [ ] `QuestionnaireHostView` routes `.tiebreaker` phase to pair view
   - [ ] Build + simulator smoke test
2. **Commit Stage 3**, then move into calibration/testing pass
3. **Tune confidence ceilings** — bump Stage 2 weights so perfect-aligned run breaches 75-85% (user earlier asked about this; deferred intentionally until after full flow exists)
4. **Add 4 more Stage 1 questions** — eye color, natural hair color, freckles, natural flush (highest info-gain additions)
5. **Extensive testing pass + tweaks** (user plan: "test extensively after we've finished, then make tweaks")
6. Move on to Phase 4: influencer combo browsing driven by saved season

## Next Steps
1. Finish the Stage 3 tiebreaker wiring (DrapingPairView badge + HostView routing + build verification)
2. Commit and run an end-to-end smoke test
3. Begin calibration pass (weight tuning, confidence thresholds, pair count tuning)
4. Add eye/hair/freckles/flush Stage 1 questions

## Future Goals (Backlog)
- Custom Sephora/Ulta product scraper for premium brand data with accurate hex codes (scaffold at `pipeline/scrapers/`)
- Community lip combo submissions — let users submit combos for their color season (design decision pending: free community data vs premium personalized matching layer)
- Spreadsheet import pipeline for external color analysis data (TikTok creator's spreadsheet with product URLs, shades, hex codes)
- Instagram/TikTok caption scraping via Apify for influencer product mentions and lip combo detection
- Discover tab enhancements: shade match percentage indicator on product cards when user has season result
- Pull Stage 2 shades from backend `/products?category=lipstick` instead of hardcoded 8-shade catalog
- Hybrid quiz+CV scoring: multiply Stage 2 posterior by CV skin-sample posterior and renormalize
- Lip landmark preview on device before A/B (let user confirm the detected lip polygon looks right)
- Manual lip-position nudge UI as a fallback if landmark detection fails
- Result sharing — export the FinalResultView as an image card for social
