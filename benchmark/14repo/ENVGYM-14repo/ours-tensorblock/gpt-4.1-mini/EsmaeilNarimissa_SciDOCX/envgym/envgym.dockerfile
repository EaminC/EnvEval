FROM python:3.10-slim

# Set working directory to repository root
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# Install UV (Universal Virtual environment manager)
RUN pip install --no-cache-dir uv

# Copy application source code and config files
COPY . /app/

# Debug info to verify files and versions
RUN ls -l /app/requirements*.txt && python --version && pip --version && uv --version

# Install Python dependencies using pip directly (bypassing uv) and prefer requirements-lock.txt if present
RUN if [ -f /app/requirements-lock.txt ]; then \
        sed -i 's/torch==2.5.1+cu121/torch==2.5.1/g' /app/requirements-lock.txt && \
        sed -i 's/torchvision==0.20.1+cu121/torchvision==0.20.1/g' /app/requirements-lock.txt && \
        pip install --no-cache-dir -r /app/requirements-lock.txt; \
    else \
        sed -i 's/torch==2.5.1+cu121/torch==2.5.1/g' /app/requirements.txt && \
        sed -i 's/torchvision==0.20.1+cu121/torchvision==0.20.1/g' /app/requirements.txt && \
        pip install --no-cache-dir -r /app/requirements.txt; \
    fi

# Create models and outputs directories if not existing
RUN mkdir -p /app/models /app/data/output /app/data/mmrag-output

# Set PYTHONPATH environment variable to include /app source code
ENV PYTHONPATH=/app

# Set environment variable to disable GPU usage
ENV CUDA_VISIBLE_DEVICES=""

# Expose port 8000 for API server
EXPOSE 8000

# Default shell
CMD ["/bin/bash"]