FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libvips-dev \
    openslide-tools \
    libopencv-core-dev \
    libopencv-imgproc-dev \
    libsnappy-dev \
    libgeos-dev \
    llvm \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip setuptools wheel

# Install pre-commit and linting tools
RUN pip install \
    pre-commit \
    black==23.1.0 \
    ruff==0.3.4 \
    pre-commit-hooks==4.4.0 \
    conventional-pre-commit==2.1.1

# Install PyTorch (CPU-only), torchvision, torchaudio
RUN pip install \
    torch==2.2.2 \
    torchvision==0.17.2 \
    torchaudio==2.2.2

# Install cellvit first
RUN pip install cellvit==1.0.9

# Install remaining dependencies in smaller batches for better error visibility
RUN pip install colorama colour natsort tqdm psutil pyaml ujson==5.8.0
RUN pip install "einops>=0.6.1" "geojson>=2.0.0" "opt-einsum>=3.3.0" pandas
RUN pip install "numpy<2.0.0"
RUN pip install "numba>=0.58.0"
RUN pip install opencv-python-headless==4.7.0.72
RUN pip install "pathopatch>=1.0.9"
RUN pip install "pydantic>=1.10.16,<2.0" "pydicom==2.4.4"
RUN pip install "ray[default]>=2.9.3"
RUN pip install "scikit-image>=0.19.3,<0.27" "scipy>=1.8.0"
RUN pip install "Shapely>=1.8.5.post1,<=2.0.5"
RUN pip install python-snappy openslide-python

WORKDIR /CellViT-Inference

COPY . .

RUN if [ -f pyproject.toml ]; then pip install .; fi

RUN if [ ! -d .git ]; then git init; fi

ENTRYPOINT ["/bin/bash"]