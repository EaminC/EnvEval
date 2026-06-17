FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

WORKDIR /Kilosort4

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    bzip2 \
    ca-certificates \
    build-essential \
    libglib2.0-0 \
    libxrender1 \
    libsm6 \
    libxext6 \
    pandoc \
    make \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda clean -afy

RUN $CONDA_DIR/bin/conda update -n base -c defaults conda -y || true

RUN $CONDA_DIR/bin/conda config --add channels conda-forge
RUN $CONDA_DIR/bin/conda config --set channel_priority strict

COPY setup.py setup.py
COPY docs/requirements.txt docs/requirements.txt
COPY tox.ini tox.ini
COPY pytest.ini pytest.ini
COPY docs/Makefile docs/Makefile
COPY docs/make.bat docs/make.bat
COPY docs/conf.py docs/conf.py
COPY . .

SHELL ["/bin/bash", "-c"]

RUN set -e && \
    source $CONDA_DIR/etc/profile.d/conda.sh && \
    conda create -y -n kilosort python=3.10 && \
    conda activate kilosort && \
    pip install --upgrade pip setuptools wheel && \
    pip install 'numpy>=1.20.0' scipy scikit-learn tqdm numba faiss-cpu && \
    conda install -y -c pytorch cpuonly pytorch && \
    conda install -y pyqt matplotlib && \
    pip install pyqtgraph>=0.13.0 qtpy && \
    pip install sphinx>=3.0 sphinxcontrib-apidoc nbsphinx myst_parser sphinx_rtd_theme && \
    pip install pytest pytest-cov pytest-xvfb py && \
    pip install .[gui] && \
    pip install -r docs/requirements.txt

ENV CUDA_VISIBLE_DEVICES=""
ENV PATH=$CONDA_DIR/envs/kilosort/bin:$PATH
ENV CONDA_DEFAULT_ENV=kilosort

WORKDIR /Kilosort4

CMD ["/bin/bash"]