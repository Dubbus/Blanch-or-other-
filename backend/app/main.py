from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import auth, seasons, products, influencers, combos, analysis, subscriptions


def create_app() -> FastAPI:
    app = FastAPI(title="Blanch API", version="0.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
    app.include_router(seasons.router, prefix="/api/v1/seasons", tags=["seasons"])
    app.include_router(products.router, prefix="/api/v1/products", tags=["products"])
    app.include_router(influencers.router, prefix="/api/v1/influencers", tags=["influencers"])
    app.include_router(combos.router, prefix="/api/v1/combos", tags=["combos"])
    app.include_router(analysis.router, prefix="/api/v1/analysis", tags=["analysis"])
    app.include_router(subscriptions.router, prefix="/api/v1/subscriptions", tags=["subscriptions"])

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return app


app = create_app()
