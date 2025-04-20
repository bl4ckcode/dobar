# Use an official Python runtime as a parent image
FROM python:alpine

# Set workdir inside container
WORKDIR /app

# Install system dependencies (optional: for psycopg2 or uvicorn)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

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

# Run FastAPI app using uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]