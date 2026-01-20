FROM python:3.11-slim

WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir .

# Copy application code
COPY dobar_payment ./dobar_payment

EXPOSE 8080

CMD ["uvicorn", "dobar_payment.api.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8080"]
