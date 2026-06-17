FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    make \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/pdf-to-podcast

COPY . .

RUN python3 -m venv .venv \
    && . .venv/bin/activate \
    && pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt \
    && pip install -r tests/requirements-test.txt

ENV PATH="/home/cc/EnvGym/data/20260501_071208_tensorblock_gpt-4.1-mini/pdf-to-podcast/.venv/bin:${PATH}"

CMD ["/bin/bash"]