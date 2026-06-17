FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV PYTHONIOENCODING=utf-8
ENV PATH="/root/.cargo/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    build-essential \
    curl \
    wget \
    git \
    vim \
    rsync \
    openssh-client \
    jq \
    lsof \
    locales \
    ca-certificates \
    libffi-dev \
    libssl-dev \
    libpq-dev \
    pkg-config \
    cmake \
    libprotobuf-dev \
    protobuf-compiler \
    libbz2-dev \
    liblzma-dev \
    libreadline-dev \
    zlib1g-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    python3.11 \
    python3.11-venv \
    python3.11-distutils \
    python3.11-dev \
    cargo \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

RUN python3.11 -m pip install --upgrade pip setuptools wheel

RUN python3.11 -m pip install hatchling

WORKDIR /root/node0

COPY . .

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustup default stable

RUN rustc --version && cargo --version && rustup show

RUN python3.11 -m pip install --upgrade git+https://github.com/learning-at-home/hivemind.git@v0.7.44

RUN python3.11 -m pip install . --verbose

CMD ["/bin/bash"]