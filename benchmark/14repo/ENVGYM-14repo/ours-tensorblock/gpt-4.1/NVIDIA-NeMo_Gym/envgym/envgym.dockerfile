FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_NO_CACHE_DIR=on

WORKDIR /workspace

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        build-essential \
        ca-certificates \
        libssl-dev \
        libffi-dev \
        openssh-client \
        gcc \
        make \
        pkg-config \
        libsndfile1 \
        ffmpeg \
        unzip \
        vim \
        less \
        tzdata \
        && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip install 'uv>=0.9.30'

COPY .python-version ./
COPY pyproject.toml pyproject.toml

RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --upgrade pip

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Diagnostic: display pyproject.toml content before install
RUN cat pyproject.toml

# Copy the rest of the repository before dependency install (so local code is available)
COPY . .

# Install build backend explicitly if necessary (setuptools, wheel)
RUN pip install --upgrade setuptools wheel

# Install project dependencies with verbose output for diagnostics
RUN uv pip install --verbose .

RUN pip install pre-commit

# Install the repository in editable mode (if applicable)
RUN if [ -f "pyproject.toml" ]; then uv pip install -e . ; \
    elif [ -f "setup.py" ]; then pip install -e . ; \
    fi

RUN chmod -R a+rwX /workspace

ENTRYPOINT ["/bin/bash"]