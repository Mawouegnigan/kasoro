from pydantic import BaseModel


class LoginRequest(BaseModel):
    phone_number: str
    pin: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"