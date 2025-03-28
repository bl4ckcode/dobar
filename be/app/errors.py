from pydantic import BaseModel
from typing import Optional, Any

class ErrorResponse(BaseModel):
    code: int            # HTTP status code (e.g., 400, 404, 422)
    type: str            # A short error type string (e.g., "BadRequest", "NotFound", "ValidationError")
    message: str         # A human-readable error message
    data: Optional[Any] = None  # Optional additional data (e.g., details in JSON)
    
class CustomHTTPException(Exception):
    def __init__(self, code: int, error_type: str, message: str, data: Optional[Any] = None):
        self.code = code
        self.error_type = error_type
        self.message = message
        self.data = data

    @classmethod
    def bad_request(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(400, "BadRequest", message or "Invalid request.", data)

    @classmethod
    def unauthorized(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(401, "Unauthorized", message or "You are not authenticated.", data)

    @classmethod
    def payment_required(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(402, "PaymentRequired", message, data)

    @classmethod
    def forbidden(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(403, "Forbidden", message, data)

    @classmethod
    def not_found(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(404, "NotFound", message or "The requested resource was not found.", data)

    @classmethod
    def conflict(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(409, "Conflict", message or "A resource with this identifier already exists.", data)

    @classmethod
    def internal_server_error(cls, message: Optional[str] = None, data: Optional[Any] = None):
        return cls(500, "InternalServerError", message, data)