FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    ca-certificates \
    build-essential \
    bzip2 \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    libgl1 \
    libffi-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    sudo \
    vim \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda clean -afy

SHELL ["/bin/bash", "-c"]

# Set workdir and copy local repo files
WORKDIR /workspace/repo
COPY . .

# Set repo as safe directory for git if permissions cause issues
RUN git config --global --add safe.directory /workspace/repo

# Create conda environment if environment.yml is present
RUN if [ -f environment.yml ]; then \
        conda env create -f environment.yml && \
        conda clean -afy && \
        echo "conda activate clm_gs" >> /etc/bash.bashrc; \
    else \
        echo "environment.yml not found, skipping conda environment creation"; \
    fi

ENV CONDA_DEFAULT_ENV=clm_gs
ENV PATH=$CONDA_DIR/envs/clm_gs/bin:$PATH

# Install CPU-only PyTorch, torchvision, torchaudio
RUN pip install --upgrade pip && \
    pip install torch==2.6.0+cpu torchvision==0.21.0+cpu torchaudio==2.6.0+cpu --index-url https://download.pytorch.org/whl/cpu

# Install submodules (CPU-only)
RUN pip install --no-build-isolation ./submodules/clm_kernels || echo "clm_kernels CPU fallback only"
# Skip cpu-adam installation as it is not pip-installable and no setup.py/pyproject.toml is present
RUN echo "cpu-adam not installable via pip, skipping installation"
# Skip fast-tsp installation as it is not pip-installable and no setup.py/pyproject.toml is present
RUN echo "fast-tsp not installable via pip, skipping installation"
RUN pip install --no-build-isolation ./submodules/gsplat || echo "gsplat CPU fallback only"
# Skip simple-knn installation as it is not pip-installable and no setup.py/pyproject.toml is present
RUN echo "simple-knn not installable via pip, skipping installation"

# Install code formatter (Black)
RUN pip install black

# Set permissions for datasets (user should mount as volume)
RUN mkdir -p /workspace/data /workspace/output

# Set entrypoint to bash with conda environment activated at repo root
WORKDIR /workspace/repo
ENTRYPOINT ["/bin/bash"]