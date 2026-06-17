FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=/opt/conda/bin:$PATH

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        git \
        ca-certificates \
        build-essential \
        libglib2.0-0 \
        libxext6 \
        libsm6 \
        libxrender1 \
        libgl1-mesa-glx \
        libgl1 \
        xvfb \
        pandoc \
        latexmk \
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-xetex \
        texlive-lang-all \
        python3-pip \
        python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (Python 3.9)
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py39_24.3.0-0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean -afy

# Set working directory
WORKDIR /workspace

# Copy repository content
COPY . /workspace

# Create environment from environment.yml if present
RUN if [ -f "environment.yml" ]; then \
        /opt/conda/bin/conda env create -f environment.yml && \
        /opt/conda/bin/conda clean -afy; \
    else \
        /opt/conda/bin/conda create -y -n kilosort python=3.9 && \
        /opt/conda/bin/conda clean -afy; \
    fi

# Install GUI and build dependencies before editable install
RUN /opt/conda/bin/conda install -n kilosort -y \
        pyqt \
        pyqtgraph \
        qtpy \
    && /opt/conda/bin/conda clean -afy

# Upgrade pip and show environment state before install
RUN /opt/conda/bin/conda run -n kilosort pip install --upgrade pip
RUN ls -l /workspace && /opt/conda/bin/conda run -n kilosort conda list

# Attempt editable install with [gui] extras; fallback to normal install if failure
RUN /opt/conda/bin/conda run -n kilosort pip install -e .[gui] || /opt/conda/bin/conda run -n kilosort pip install .[gui]

# Install docs requirements if present
RUN if [ -f docs/requirements.txt ]; then /opt/conda/bin/conda run -n kilosort pip install -r docs/requirements.txt; fi

# Set entrypoint to bash at the repository root
WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]