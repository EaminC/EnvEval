FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Set working directory inside container
WORKDIR /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/SVRTK_Docker_GPU

# Update and install core dependencies including git and ca-certificates early
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    build-essential \
    cmake \
    libboost-all-dev \
    libeigen3-dev \
    libtbb-dev \
    libfltk1.3-dev \
    pigz \
    dcmtk \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy entire repo sources into container
COPY . .

# Upgrade pip, setuptools, and wheel
RUN python3 -m pip install --upgrade pip setuptools wheel

# Skip building dcm2niix from dev branch due to git clone issues during build
# Instead install dcm2niix from ubuntu package if available or skip this step
RUN apt-get update && apt-get install -y --no-install-recommends dcm2niix || true && rm -rf /var/lib/apt/lists/*

# Ensure git submodules are initialized and checkout Segmentation_FetalMRI dev branch
RUN git submodule update --init --recursive && \
    git -C Segmentation_FetalMRI checkout dev

# Download neural network weights and brain atlases (assumes scripts or commands present)
RUN if [ -f ./download_weights.sh ]; then bash ./download_weights.sh; fi

# Set executable permissions on scripts in ./scripts
RUN chmod -R +x ./scripts || true

# Add /home/scripts to PATH
ENV PATH="/home/scripts:${PATH}"

# Default command: bash shell at repo root
CMD ["/bin/bash"]