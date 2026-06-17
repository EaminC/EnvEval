FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHON_VERSION=3.12.0
ENV PYTHON_PIP_VERSION=23.1.2

# Set working directory to repo root
WORKDIR /tao_tutorials

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    build-essential \
    ca-certificates \
    software-properties-common \
    libssl-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev \
    zlib1g-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libgdbm-dev \
    libnss3-dev \
    libsqlite3-dev \
    locales \
    jq \
    bash-completion \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

# Install pyenv dependencies and pyenv
ENV PYENV_ROOT=/root/.pyenv
ENV PATH=$PYENV_ROOT/bin:$PATH

RUN curl https://pyenv.run | bash

# Install Python 3.12.0 via pyenv and set global
RUN bash -c ' \
    export PATH=$PYENV_ROOT/bin:$PATH && \
    eval "$(pyenv init -)" && \
    pyenv install -s $PYTHON_VERSION && \
    pyenv global $PYTHON_VERSION \
'

ENV PATH=/root/.pyenv/shims:/root/.pyenv/bin:$PATH

# Upgrade pip to version > 21.06 and install essential python packages
RUN python -m ensurepip --upgrade && \
    pip install --no-cache-dir --upgrade pip==$PYTHON_PIP_VERSION setuptools wheel

# Since requirements-pip.txt does not exist in setup/tao-docker-compose, skip pip install from it

# Copy .gitignore to make sure it's present (adjust if .gitignore is in repo)
COPY .gitignore .gitignore

# Copy quickstart_launcher.sh and set executable
COPY ./setup/quickstart_launcher.sh ./setup/quickstart_launcher.sh
RUN chmod +x ./setup/quickstart_launcher.sh

# Copy secrets.json placeholder if exists
COPY ./setup/tao-docker-compose/secrets.json ./setup/secrets.json

# Expose any ports if needed (optional)
# EXPOSE 8888 80 27017 9333

# Set entrypoint to bash for CLI interaction at repo root
ENTRYPOINT ["/bin/bash"]

# Default command
CMD ["-l"]