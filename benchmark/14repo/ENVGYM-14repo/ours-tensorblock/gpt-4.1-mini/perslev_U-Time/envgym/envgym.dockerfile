FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH \
    OMP_NUM_THREADS=48 \
    MKL_NUM_THREADS=48

# Install system dependencies
RUN apt-get update --fix-missing && apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        bzip2 \
        git \
        build-essential \
        libglib2.0-0 \
        libxext6 \
        libsm6 \
        libxrender1 \
        libffi-dev \
        libssl-dev \
        tk8.6 \
        python3-tk \
        && rm -rf /var/lib/apt/lists/*

# Install Miniconda3 (latest 64-bit for Linux x86_64) - pinned to conda 4.10.3 or higher
ENV CONDA_DIR=/opt/conda
ENV MINICONDA_VERSION=py39_4.10.3
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda install -y conda=4.10.3 && \
    $CONDA_DIR/bin/conda clean -afy

# Create working directory
WORKDIR /app

# Copy repository files
COPY . /app

# Initialize conda and update conda base separately with verbose output for debugging
RUN /bin/bash -c "source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda update -n base -c defaults conda -y -v"

# Create conda environment from environment.yaml with explicit python version 3.9 enforced and verbose output
RUN /bin/bash -c "source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda env create -f /app/environment.yaml -v && \
    conda activate u-sleep && \
    conda install -y python=3.9 && \
    conda clean -afy"

# Activate environment and upgrade pip, setuptools, wheel, then install all pip packages from requirements.txt (including tensorflow if specified)
RUN /bin/bash -c "source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda activate u-sleep && \
    pip install --upgrade pip setuptools wheel && \
    pip install -r /app/requirements.txt -v"

# Install the U-Time package via setup.py
RUN /bin/bash -c "source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda activate u-sleep && \
    pip install /app"

# Set entrypoint to bash with conda environment activated
SHELL ["/bin/bash", "-c"]
CMD source /opt/conda/etc/profile.d/conda.sh && conda activate u-sleep && exec /bin/bash -l