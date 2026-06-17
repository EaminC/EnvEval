FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgl1-mesa-glx \
    libgeos-dev \
    libopencv-dev \
    python3-opencv \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy project files
COPY . /workspace/

# Install Python dependencies (CPU versions)
RUN pip install --no-cache-dir \
    torch==2.0.1+cpu torchvision==0.15.2+cpu -f https://download.pytorch.org/whl/torch_stable.html \
    numpy \
    opencv-python \
    pillow \
    scikit-image \
    matplotlib \
    jupyter \
    pandas \
    tqdm \
    scipy \
    h5py \
    tensorboard \
    albumentations \
    shapely \
    openslide-python \
    zarr \
    numba \
    pyyaml \
    click \
    wandb \
    seaborn

# Install any requirements.txt if it exists
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Install the package if setup.py exists
RUN if [ -f setup.py ]; then pip install -e .; fi

# Set environment variables for CPU optimization
ENV OMP_NUM_THREADS=4
ENV MKL_NUM_THREADS=4
ENV PYTHONPATH=/workspace:$PYTHONPATH

# Expose port for Jupyter if needed
EXPOSE 8888

CMD ["/bin/bash"]