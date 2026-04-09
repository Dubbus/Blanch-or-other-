from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel


class RegisterIn(CamelModel):
    email: str
    display_name: str
    password: str


class LoginIn(CamelModel):
    email: str
    password: str


class UserOut(CamelModel):
    id: str
    display_name: str
    email: str
    avatar_url: str | None = None
    subscription_tier: str = "free"
    created_at: str

    @field_validator("id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)

    @field_validator("created_at", mode="before")
    @classmethod
    def coerce_date(cls, v: Any) -> str:
        return str(v)[:10] if v else ""


class AuthResponse(CamelModel):
    access_token: str
    user: UserOut
