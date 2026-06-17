FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONIOENCODING=utf-8

# Install system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      curl \
      jq \
      python3 \
      python3-pip \
      ca-certificates \
      git \
      lsb-release \
      sudo \
      bash \
      build-essential \
      wget \
      tar && \
    rm -rf /var/lib/apt/lists/*

# Install gum (fixed version, robust extraction with direct move and cleanup)
RUN set -ex && \
    GUM_VERSION="v0.13.0" && \
    ARCH=amd64 && \
    GUM_FILENAME="gum_${GUM_VERSION#v}_linux_${ARCH}.tar.gz" && \
    GUM_URL="https://github.com/charmbracelet/gum/releases/download/${GUM_VERSION}/${GUM_FILENAME}" && \
    wget -O gum.tar.gz "$GUM_URL" && \
    tar --wildcards --strip-components=1 -xzf gum.tar.gz '*/gum' && \
    mv gum /usr/local/bin/gum && \
    chmod +x /usr/local/bin/gum && \
    /usr/local/bin/gum --version && \
    rm -rf gum.tar.gz

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Set working directory to repository root
WORKDIR /nesa_bootstrap

# Copy repository contents (assumes Docker build context is repository root)
COPY . .

# Download Nesa bootstrap script and make it executable
RUN curl -O https://raw.githubusercontent.com/nesaorg/bootstrap/master/bootstrap.sh && \
    chmod +x bootstrap.sh

# Create necessary directories for Nesa environment and logs
RUN mkdir -p /root/.nesa/env /root/.nesa/logs

# Ensure overlay2 storage driver is used if available (for tests, not enforced)
RUN if command -v docker >/dev/null 2>&1; then \
      if docker info | grep -q 'overlay2'; then echo "overlay2 storage driver supported"; else echo "overlay2 storage driver not detected"; fi; \
    else \
      echo "docker command not found, skipping overlay2 check"; \
    fi || true

# Set default shell to bash and launch interactive CLI at container start
CMD ["/bin/bash"]