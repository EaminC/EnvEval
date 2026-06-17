FROM pytorch/pytorch:1.9.0-cpu

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git wget curl unzip pigz dcmtk \
        build-essential cmake cmake-curses-gui \
        libboost-all-dev libeigen3-dev libtbb-dev libfltk1.3-dev \
        ca-certificates \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-dev \
        locales \
        && rm -rf /var/lib/apt/lists/*

# Set UTF-8 locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Set workdir at repo root
WORKDIR /home

# Copy MIRTK and SVRTK sources into image
COPY MIRTK /home/MIRTK
COPY SVRTK /home/MIRTK/Packages/SVRTK

# Build and install MIRTK (with SVRTK as package)
RUN mkdir -p /home/MIRTK/build && \
    cd /home/MIRTK/build && \
    cmake -DUSE_FLTK=ON -DUSE_SVRTK=ON .. && \
    make -j$(nproc) && \
    make install

ENV PATH="/home/MIRTK/build/bin:${PATH}"

# Build and install dcm2niix from development branch
RUN git clone --depth 1 --branch development https://github.com/rordenlab/dcm2niix.git /home/dcm2niix && \
    mkdir -p /home/dcm2niix/build && \
    cd /home/dcm2niix/build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

ENV PATH="/home/dcm2niix/build/bin:${PATH}"

# Copy Segmentation_FetalMRI code and weights
COPY Segmentation_FetalMRI /home/Segmentation_FetalMRI

# Download pretrained weights if not already present
RUN mkdir -p /home/Segmentation_FetalMRI/trained-models && \
    cd /home/Segmentation_FetalMRI/trained-models && \
    [ -f latest.ckpt ] || wget -O checkpoints-brain-loc-2-labels/latest.ckpt https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels/latest.ckpt && \
    [ -f latest.ckpt ] || wget -O checkpoints-brain-loc-2-labels-cropped/latest.ckpt https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels-cropped/latest.ckpt && \
    [ -f latest.ckpt ] || wget -O checkpoints-brain-reo-5-labels/latest.ckpt https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-reo-5-labels/latest.ckpt && \
    [ -f latest.ckpt ] || wget -O checkpoints-brain-reo-5-labels-raw-stacks/latest.ckpt https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-reo-5-labels-raw-stacks/latest.ckpt

# Copy reference-templates if present
COPY Segmentation_FetalMRI/reference-templates /home/Segmentation_FetalMRI/reference-templates

# Copy pipeline scripts and make them executable
COPY scripts /home/scripts
RUN chmod -R +x /home/scripts

# Copy recon folder if present
COPY recon /home/recon

# Install Python requirements for Segmentation_FetalMRI
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /home/Segmentation_FetalMRI/requirements.txt

# Make sure MIRTK and SVRTK binaries are in PATH
ENV PATH="/home/MIRTK/build/bin:${PATH}"

# Set default workdir to repo root
WORKDIR /home

# Set entrypoint to bash shell
ENTRYPOINT ["/bin/bash"]