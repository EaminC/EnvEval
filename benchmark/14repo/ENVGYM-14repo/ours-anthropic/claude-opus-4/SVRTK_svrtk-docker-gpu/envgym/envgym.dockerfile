FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3-pip \
    python3-dev \
    dcm2niix \
    openssh-client \
    sudo \
    libboost-all-dev \
    libeigen3-dev \
    libflann-dev \
    libfreeimage-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libhdf5-dev \
    libjpeg-dev \
    liblz4-dev \
    libpng-dev \
    libqhull-dev \
    libqt5opengl5-dev \
    libtiff-dev \
    libvtk9-dev \
    libvtk9-qt-dev \
    libxml2-dev \
    libzstd-dev \
    pkg-config \
    qtbase5-dev \
    libtbb-dev \
    libinsighttoolkit4-dev \
    libfftw3-dev \
    libsuitesparse-dev \
    liblapack-dev \
    libblas-dev \
    libarmadillo-dev \
    libgtest-dev \
    libnifti-dev \
    libpng-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    numpy \
    scipy \
    nibabel \
    SimpleITK \
    scikit-image \
    matplotlib \
    pandas \
    pydicom \
    pytorch-lightning==1.9.5 \
    torch==1.13.1+cpu \
    torchvision==0.14.1+cpu \
    tqdm \
    -f https://download.pytorch.org/whl/torch_stable.html

# Set working directory
WORKDIR /workspace

# Clone the repository without submodules first
RUN git clone https://github.com/SVRTK/svrtk-docker-gpu.git SVRTK_Docker_GPU

# Set the repository as working directory
WORKDIR /workspace/SVRTK_Docker_GPU

# Clone MIRTK directly from official repository with a stable release
RUN rm -rf MIRTK && \
    git clone --depth 1 --branch v2.0.0 https://github.com/BioMedIA/MIRTK.git MIRTK

# Configure MIRTK
RUN cd MIRTK && \
    mkdir -p build && \
    cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DWITH_TBB=ON \
        -DBUILD_TESTING=OFF \
        -DBUILD_DOCUMENTATION=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DCMAKE_CXX_STANDARD=14 \
        -DCMAKE_VERBOSE_MAKEFILE=ON \
        -DWITH_VTK=OFF \
        -DWITH_PNG=ON \
        -DWITH_ZLIB=ON

# Build MIRTK
RUN cd MIRTK/build && \
    make -j$(nproc) || make -j1 VERBOSE=1

# Install MIRTK
RUN cd MIRTK/build && \
    make install

# Initialize and update SVRTK submodule
RUN git submodule init SVRTK && \
    git submodule update --force SVRTK

# Build SVRTK
RUN cd SVRTK && \
    mkdir -p build && \
    cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_PREFIX_PATH=/usr/local \
        -DMIRTK_DIR=/usr/local/lib/cmake/mirtk && \
    make -j$(nproc) && \
    make install

# Initialize and update Segmentation_FetalMRI submodule
RUN git submodule init Segmentation_FetalMRI && \
    git submodule update --force Segmentation_FetalMRI

# Create required directory structure
RUN mkdir -p recon/pride/SVR \
    recon/pride/TempOutputSeries \
    recon/pride/TempInputSeries \
    recon/pride/logs \
    recon/svr_processing_files

# Create model directories
RUN mkdir -p Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-2-labels \
    Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-2-labels-cropped \
    Segmentation_FetalMRI/trained-models/checkpoints-brain-reo-5-labels \
    Segmentation_FetalMRI/trained-models/checkpoints-brain-reo-5-labels-raw-stacks

# Make scripts executable
RUN chmod +x scripts/*.bash

# Set environment variables
ENV PATH="/usr/local/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"
ENV PYTHONIOENCODING=utf-8

# Set the working directory to the repository root
WORKDIR /workspace/SVRTK_Docker_GPU

# Default command
CMD ["/bin/bash"]