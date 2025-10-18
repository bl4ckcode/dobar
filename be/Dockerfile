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

    # Copy only git-related things first to initialize submodule
COPY .git .git
COPY .gitmodules .gitmodules

# Clone submodule
RUN git submodule update --init --recursive

# Copy rest of the code
COPY . .

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 8080

# Environment hint: pymongo/motor can rely on certifi; disabling OCSP checks helps in some container networks
ENV PYTHONHTTPSVERIFY=1 \
    PYMONGO_DISABLE_OCSP_ENDPOINT_CHECK=true

# Run FastAPI app using uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]