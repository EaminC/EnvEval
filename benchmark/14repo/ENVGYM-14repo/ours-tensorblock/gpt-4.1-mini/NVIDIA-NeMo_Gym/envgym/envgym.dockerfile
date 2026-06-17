FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        curl \
        ca-certificates \
        libssl-dev \
        libffi-dev \
        python3-dev \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /NeMo_Gym

COPY . /NeMo_Gym

RUN python -m pip install --upgrade pip setuptools wheel

CMD ["/bin/bash"]