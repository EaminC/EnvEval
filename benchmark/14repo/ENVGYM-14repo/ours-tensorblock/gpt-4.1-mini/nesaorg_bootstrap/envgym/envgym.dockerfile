FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

WORKDIR /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/nesa_bootstrap

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    python3 \
    python3-pip \
    bash \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python

COPY . /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/nesa_bootstrap

RUN if [ -f /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/nesa_bootstrap/requirements.txt ]; then pip3 install --no-cache-dir -r /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/nesa_bootstrap/requirements.txt; fi

RUN if ! getent group cc >/dev/null; then groupadd -g 1000 cc; fi \
    && if ! id -u cc >/dev/null 2>&1; then useradd -m -u 1000 -g cc -s /bin/bash cc; fi \
    && if getent group sudo >/dev/null && ! id -nG cc | grep -qw sudo; then usermod -aG sudo cc; fi \
    && if getent group docker >/dev/null && ! id -nG cc | grep -qw docker; then usermod -aG docker cc; fi

RUN echo "cc ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cc \
    && chmod 440 /etc/sudoers.d/cc

RUN chown -R cc:cc /home/cc

ENV NESA_BOOTSTRAP_DIR=/home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/nesa_bootstrap

USER cc
SHELL ["/bin/bash", "-c"]

CMD ["bash"]