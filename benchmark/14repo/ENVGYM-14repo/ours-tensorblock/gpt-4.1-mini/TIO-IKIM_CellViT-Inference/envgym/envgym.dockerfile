FROM python:3.10-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CELLVIT_CACHE_DIR=/root/.cache/cellvit

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    llvm \
    libvips \
    libvips-dev \
    libopencv-core-dev \
    libopencv-imgproc-dev \
    libsnappy-dev \
    libgeos-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    openslide-tools \
    libopenslide-dev \
    ca-certificates \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch CPU-only versions and related packages
RUN pip install --no-cache-dir \
    torch==2.2.2+cpu \
    torchvision==0.17.2+cpu \
    torchaudio==2.2.2 \
    --index-url https://download.pytorch.org/whl/cpu

# Install pre-commit and code quality tools
RUN pip install --no-cache-dir \
    pre-commit \
    black==23.1.0 \
    ruff==0.3.4 \
    conventional-pre-commit==2.1.1

# Clone or copy repository content into /workspace here
# Assumes Docker build context includes the repo, copy all files
COPY . /workspace/

# Install python package (cellvit) and dependencies from local source
RUN pip install --no-cache-dir .

# Install OpenSlide Python bindings explicitly if not included
RUN pip install --no-cache-dir openslide-python

# Expose cache directory environment variable
ENV CELLVIT_CACHE_DIR=/root/.cache/cellvit

# Set default shell to bash and working directory to repo root
CMD ["/bin/bash"]