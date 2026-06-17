FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PYTHONUNBUFFERED=1
ENV CELLVIT_CACHE=/workspace/CellViT-Inference/.cache/cellvit

RUN apt-get update && apt-get install -y \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    git \
    make \
    wget \
    curl \
    libvips \
    libvips-dev \
    openslide-tools \
    gcc \
    g++ \
    libopencv-core-dev \
    libopencv-imgproc-dev \
    libsnappy-dev \
    libgeos-dev \
    llvm \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libgomp1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace/CellViT-Inference

RUN pip install --upgrade pip setuptools wheel build

RUN pip install torch==2.2.2 torchvision==0.17.2 torchaudio==2.2.2 --index-url https://download.pytorch.org/whl/cpu

RUN pip install \
    opencv-python-headless==4.7.0.72 \
    "numpy<2.0.0" \
    "scikit-image>=0.19.3,<0.27" \
    "Shapely>=1.8.5.post1,<=2.0.5" \
    "pydantic>=1.10.16,<2.0" \
    "ray[default]>=2.9.3" \
    "pathopatch>=1.0.9" \
    pytest>=7.0.0 \
    pytest-cov>=4.0.0 \
    pytest-mock>=3.10.0 \
    black==23.1.0 \
    ruff==0.3.4 \
    pre-commit \
    sphinx>=4.0.0 \
    sphinx-rtd-theme \
    sphinx-autodoc-typehints \
    myst-parser \
    sphinx-collapse \
    sphinx-copybutton \
    sphinx-design \
    sphinx-material \
    sphinx-notfound-page \
    sphinx-tabs \
    sphinxawesome-theme \
    sphinxcontrib-applehelp \
    sphinxcontrib-devhelp \
    sphinxcontrib-htmlhelp \
    sphinxcontrib-jquery \
    sphinxcontrib-jsmath \
    sphinxcontrib-qthelp \
    sphinxcontrib-serializinghtml

COPY . /workspace/CellViT-Inference/

RUN mkdir -p .cache/cellvit

RUN git init && \
    git config --global user.email "docker@cellvit.local" && \
    git config --global user.name "Docker User"

RUN pip install -e .

CMD ["/bin/bash"]