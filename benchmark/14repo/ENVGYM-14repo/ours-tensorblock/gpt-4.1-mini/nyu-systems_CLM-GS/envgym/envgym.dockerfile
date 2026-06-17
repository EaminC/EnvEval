FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    gcc \
    g++ \
    make \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3-setuptools \
    python3-venv \
    libgl1-mesa-glx \
    libglib2.0-0 \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Symlink python3.10 to python and upgrade pip
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    python -m pip install --upgrade pip setuptools wheel

# Install Miniconda (latest for Linux x86_64)
ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh

ENV PATH=$CONDA_DIR/bin:$PATH

# Initialize conda for bash shell in Docker RUN steps
RUN $CONDA_DIR/bin/conda init bash

SHELL ["/bin/bash", "-c"]

# Create conda environment clm_gs_cpu with python 3.10 using sourced conda.sh
RUN source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda create -n clm_gs_cpu python=3.10 -y && \
    conda clean -afy

# Upgrade pip and install required packages inside conda environment using conda run
RUN source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda run -n clm_gs_cpu python -m pip install --upgrade pip setuptools wheel && \
    conda run -n clm_gs_cpu pip install \
      torch==2.6.0+cpu \
      torchvision==0.21.0+cpu \
      torchaudio==2.6.0 \
      --extra-index-url https://download.pytorch.org/whl/cpu && \
    conda run -n clm_gs_cpu pip install \
      tqdm \
      plyfile \
      psutil \
      numba \
      opencv-python \
      scipy \
      matplotlib \
      pandas \
      imageio \
      imageio-ffmpeg \
      requests \
      tabulate \
      black

WORKDIR /root

# Clone the main repository with submodules
RUN git clone --recursive https://github.com/nyu-systems/CLM-GS.git /root/CLM-GS

WORKDIR /root/CLM-GS

# Update submodules recursively (in case)
RUN git submodule update --init --recursive

# Install CPU-compatible submodules only, skipping clm_kernels (due to CUDA dependency)
RUN source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda run -n clm_gs_cpu pip install --no-build-isolation ./submodules/cpu-adam && \
    conda run -n clm_gs_cpu pip install ./submodules/fast-tsp && \
    conda run -n clm_gs_cpu pip install --no-build-isolation ./submodules/gsplat && \
    conda run -n clm_gs_cpu pip install --no-build-isolation ./submodules/simple-knn

# Set default shell to bash and start at repo root with conda environment activated using conda run
CMD ["/bin/bash", "-c", "source /opt/conda/etc/profile.d/conda.sh && conda activate clm_gs_cpu && exec /bin/bash"]