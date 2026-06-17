FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH \
    CONDA_DIR=/opt/conda \
    PYTHONNOUSERSITE=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        git \
        ca-certificates \
        build-essential \
        gcc \
        g++ \
        binutils \
        make \
        libvips-dev \
        libjpeg-dev \
        libpng-dev \
        zlib1g-dev \
        libtiff-dev \
        libopenslide-dev \
        gdal-bin \
        libgdal-dev \
        python3-pip \
        python3-dev \
        python3-setuptools \
        python3-wheel \
        htop \
        tmux \
        unzip \
        locales \
        pkg-config \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py310_23.10.0-1-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda clean -afy

RUN conda update -n base -c defaults conda && \
    conda install -y python=3.10 && \
    conda clean -afy

RUN conda install -y -c conda-forge gdal openslide-python && conda clean -afy

SHELL ["/bin/bash", "-c"]

WORKDIR /CellViT-plus-plus

COPY requirements.txt ./requirements.txt

RUN pip install --upgrade pip && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

RUN pip install torch==2.2.1 torchvision==0.17.1 torchaudio==2.2.1

RUN pip install jupyter notebook jupyterlab \
    pytest pre-commit black flake8 ruff pip-tools

RUN if [ -f setup.py ]; then pip install -e .; fi

CMD ["/bin/bash"]