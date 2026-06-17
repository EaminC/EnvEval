FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    ca-certificates \
    build-essential \
    python3.10 \
    python3.10-venv \
    python3.10-distutils \
    python3-pip \
    unzip \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Set python3 to point to python3.10
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Upgrade pip to 23.0 and install packaging module first
RUN python3 -m pip install --no-cache-dir --upgrade pip==23.0 setuptools packaging

WORKDIR /root

# Clone Fooocus repository
RUN git clone https://github.com/lllyasviel/Fooocus.git

WORKDIR /root/Fooocus

# Create Python virtual environment and install dependencies
RUN python3 -m venv fooocus_env

# Activate venv and install pinned packages
RUN /bin/bash -c "\
    source fooocus_env/bin/activate && \
    pip install --no-cache-dir --upgrade pip==23.0 && \
    pip install --no-cache-dir packaging && \
    pip install --no-cache-dir -r requirements_versions.txt \
"

# Expose port 7860 (default for gradio apps) for potential GUI access
EXPOSE 7860

# Set environment variables for python and venv activation convenience
ENV VIRTUAL_ENV=/root/Fooocus/fooocus_env
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Default to bash shell in repository root with virtualenv activated
CMD ["/bin/bash", "-c", "source fooocus_env/bin/activate && exec bash"]