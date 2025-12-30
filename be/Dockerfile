# syntax=docker/dockerfile:1.4
# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set workdir inside container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    ca-certificates \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Ensure CA store exists and is up to date
RUN update-ca-certificates

# Copy application code
COPY . .

# Install dependencies with GitHub token for private repos
# The token is passed as a build secret and never stored in the image
COPY requirements.txt .
RUN --mount=type=secret,id=GITHUB_TOKEN \
    GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir "dobar-payment-engine @ git+https://${GITHUB_TOKEN}@github.com/bl4ckcode/dobar-payment-engine.git@main"

# Expose port
EXPOSE 8080

# Environment hint: pymongo/motor can rely on certifi; disabling OCSP checks helps in some container networks
ENV PYTHONHTTPSVERIFY=1 \
    PYMONGO_DISABLE_OCSP_ENDPOINT_CHECK=true

# Run FastAPI app using uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]