FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        pandoc \
        curl \
        build-essential \
        ca-certificates \
        libglib2.0-0 \
        libsm6 \
        libxrender1 \
        libxext6 \
        libmagic1 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements files first for layer caching
COPY requirements.txt requirements.txt
COPY requirements-lock.txt requirements-lock.txt

# Install pip, uv (optional), and upgrade setuptools
RUN pip install --upgrade pip setuptools wheel && \
    pip install uv

# Install python dependencies (CPU-only torch/torchvision/timm enforced via requirements.txt)
RUN uv pip install --system --require-hashes -r requirements-lock.txt || \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the repository
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app

# Create models and outputs directories if not exist (for volume mounts)
RUN mkdir -p /app/models /app/outputs

# Set permissions (in case of non-root use later)
RUN chmod -R a+rw /app/models /app/outputs

# Expose API port
EXPOSE 8000

# Set entrypoint to bash
ENTRYPOINT ["/bin/bash"]