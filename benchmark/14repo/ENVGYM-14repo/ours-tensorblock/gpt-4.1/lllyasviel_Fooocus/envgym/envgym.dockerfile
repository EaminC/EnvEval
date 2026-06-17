FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        libssl-dev \
        libffi-dev \
        libglib2.0-0 \
        libsm6 \
        libxrender1 \
        libxext6 \
        libgl1 \
        ca-certificates \
        unzip \
        wget \
        && rm -rf /var/lib/apt/lists/*

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# Create workspace
WORKDIR /workspace

# Clone Fooocus repository
RUN git clone https://github.com/lllyasviel/Fooocus.git . 

# Copy requirements_versions.txt and environment.yaml if present (for efficient caching, these should be added before)
# Uncomment if you want to ADD your custom requirements/environment files during build
# COPY requirements_versions.txt environment.yaml ./

# Upgrade pip to >=23.0 and install venv
RUN python -m pip install --upgrade pip==23.0 && \
    python -m pip install packaging

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip in venv and install dependencies
RUN pip install --upgrade pip==23.0

# Install PyTorch CPU-only wheels
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install all other required packages with pinned versions
RUN pip install \
    torchsde==0.2.5 \
    einops==0.4.1 \
    transformers==4.30.2 \
    safetensors==0.3.1 \
    accelerate==0.21.0 \
    pyyaml==6.0 \
    Pillow==9.2.0 \
    scipy==1.9.3 \
    tqdm==4.64.1 \
    psutil==5.9.5 \
    pytorch_lightning==1.9.4 \
    omegaconf==2.2.3 \
    gradio==3.41.2 \
    pygit2==1.12.2 \
    opencv-contrib-python==4.8.0.74 \
    httpx==0.24.1 \
    onnxruntime==1.16.3 \
    timm==0.9.2

# Set shell to bash by default
SHELL ["/bin/bash", "-c"]

# Set entrypoint to bash in interactive mode at repo root
ENTRYPOINT ["/bin/bash"]