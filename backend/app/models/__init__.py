# Import all models so Alembic sees the metadata
from app.models.user import User  # noqa: F401
from app.models.color_season import ColorSeason  # noqa: F401
from app.models.product import Product, ProductSeasonMap  # noqa: F401
from app.models.influencer import Influencer, InfluencerSeasonMap  # noqa: F401
from app.models.product_mention import ProductMention  # noqa: F401
from app.models.lip_combo import LipCombo, LipComboItem  # noqa: F401
from app.models.analysis import UserAnalysisResult  # noqa: F401
from app.models.saved_product import UserSavedProduct  # noqa: F401
