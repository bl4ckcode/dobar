FROM python:3.11-slim

WORKDIR /app

# Copy all source files first
COPY pyproject.toml ./
COPY dobar_payment ./dobar_payment

# Install the package (includes uvicorn from dependencies)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ".[api]"

EXPOSE 8080

CMD ["uvicorn", "dobar_payment.api.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8080"]
