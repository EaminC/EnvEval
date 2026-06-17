FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install basic utilities and system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      software-properties-common \
      apt-transport-https \
      ca-certificates \
      wget \
      curl \
      git \
      tar \
      unzip \
      gzip \
      rsync \
      openssh-client \
      jq \
      postgresql-client \
      nginx \
      build-essential \
      libssl-dev \
      libffi-dev \
      libpq-dev \
      libxml2-dev \
      libxslt1-dev \
      zlib1g-dev \
      libbz2-dev \
      libreadline-dev \
      libsqlite3-dev \
      libncursesw5-dev \
      libgdbm-dev \
      liblzma-dev \
      tk-dev \
      libcurl4-openssl-dev \
      libfreetype6-dev \
      pkg-config \
      locales \
      vim \
      nano \
      net-tools \
      iputils-ping \
      openssl \
      ssh \
      lsof \
      sudo \
      less \
      python3-distutils \
      python3-venv \
      python3-pip \
      && rm -rf /var/lib/apt/lists/*

# Use Ubuntu native Python 3.10 for 22.04
RUN ln -sf /usr/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/bin/python3.10 /usr/local/bin/python

# Ensure locale is set (for Python and Jupyter)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Upgrade pip
RUN python3 -m pip install --upgrade "pip>=21.1"

RUN python3 -m pip install --no-cache-dir \
      notebook \
      jupyterlab \
      ipykernel \
      ipywidgets \
      jupyter_contrib_nbextensions \
      jupyterthemes \
      requests

RUN python3 -m pip install --no-cache-dir awscli s3cmd

WORKDIR /tmp
RUN git clone https://github.com/NVIDIA/tao_tutorials.git /opt/tao_tutorials

RUN mkdir -p /workspace && cp -r /opt/tao_tutorials/. /workspace/

WORKDIR /workspace

RUN if [ -f requirements.txt ]; then python3 -m pip install --no-cache-dir -r requirements.txt; fi

RUN if [ -f notebooks/tao_launcher_starter_kit/deps/requirements-pip.txt ]; then python3 -m pip install --no-cache-dir -r notebooks/tao_launcher_starter_kit/deps/requirements-pip.txt; fi

RUN chmod -R a+rwX /workspace

ENV TAO_CPU_MODE=true
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

EXPOSE 8888 8090 8443 27017 9333 8333 8080

ENTRYPOINT ["/bin/bash"]