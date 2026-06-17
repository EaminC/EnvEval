FROM python:3.11-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    UV_CACHE_DIR=/tmp/uv-cache

# Set working directory
WORKDIR /home/cc/EnvGym/data/20260501_153628_tensorblock_gpt-4.1/pdf-to-podcast

# System dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        make \
        curl \
        wget \
        procps \
        libgl1 \
        libglib2.0-0 \
        sox \
        libsox-fmt-all \
        libsox-fmt-mp3 \
        libsndfile1-dev \
        ffmpeg \
        man \
        less \
        unzip \
        unar \
        aria2 \
        tmux \
        vim \
        openssl \
        libssl-dev \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Optional: openssh-server (comment out if not needed)
# RUN apt-get update && apt-get install -y --no-install-recommends openssh-server && rm -rf /var/lib/apt/lists/*

# Install uv (Python dependency manager)
RUN pip install --upgrade pip && \
    pip install uv

# Copy repository files into container
COPY . .

# Install Python dependencies (prefer uv for speed and reproducibility)
RUN if [ -f requirements.txt ]; then uv pip install --system -r requirements.txt ; fi
RUN if [ -f requirements-dev.txt ]; then uv pip install --system -r requirements-dev.txt ; fi
RUN if [ -f services/TTSService/requirements.txt ]; then uv pip install --system -r services/TTSService/requirements.txt ; fi
RUN if [ -f services/PDFService/PDFModelService/requirements.api.txt ]; then uv pip install --system -r services/PDFService/PDFModelService/requirements.api.txt ; fi
RUN if [ -f services/PDFService/PDFModelService/requirements.worker.txt ]; then uv pip install --system -r services/PDFService/PDFModelService/requirements.worker.txt ; fi

# For editable installs (optional, e.g. for shared packages)
RUN if [ -f frontend/shared/setup.py ]; then pip install -e frontend/shared ; fi

# Ensure correct permissions for working directory
RUN chown -R root:root /home/cc/EnvGym/data/20260501_153628_tensorblock_gpt-4.1/pdf-to-podcast

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

# Entrypoint: drop into an interactive bash shell at the repo root
ENTRYPOINT ["/bin/bash"]