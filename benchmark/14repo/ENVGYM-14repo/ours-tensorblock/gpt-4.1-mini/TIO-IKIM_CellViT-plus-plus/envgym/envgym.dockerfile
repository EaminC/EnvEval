FROM python:3.10-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH=/opt/conda/bin:$PATH \
    CONDA_DIR=/opt/conda

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    build-essential \
    git \
    curl \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    gdal-bin \
    libgdal-dev \
    openslide-tools \
    libvips-dev \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    vim \
    less \
    zip \
    unzip \
    pkg-config \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh

ENV PATH=$CONDA_DIR/bin:$PATH

SHELL ["/bin/bash", "-c"]

WORKDIR /app

COPY environment.yaml environment.yaml
COPY viewer/SlideProvider/environment.yml viewer/SlideProvider/environment.yml
COPY requirements.txt requirements.txt
COPY viewer/SlideProvider/requirements.txt viewer/SlideProvider/requirements.txt

RUN conda update -n base -c defaults conda -y && \
    conda config --set channel_priority strict && \
    conda config --add channels defaults && \
    conda config --add channels conda-forge && \
    conda config --add channels bioconda && \
    conda info && \
    conda config --show

RUN conda env create -f environment.yaml -v && \
    conda clean -afy

SHELL ["conda", "run", "-n", "cellvit_env", "/bin/bash", "-c"]

RUN pip install --no-cache-dir torch==2.2.2+cpu torchvision==0.17.2+cpu torchaudio==2.2.2+cpu -f https://download.pytorch.org/whl/torch_stable.html

RUN pip install --no-cache-dir -r requirements.txt

RUN conda env create -f viewer/SlideProvider/environment.yml -v && \
    conda clean -afy

RUN conda run -n fastapi_patho pip install --no-cache-dir -r viewer/SlideProvider/requirements.txt

COPY . /app

RUN chmod -R a+rX /app

ENV PATH=$CONDA_DIR/envs/cellvit_env/bin:$PATH
ENV CONDA_DEFAULT_ENV=cellvit_env
ENV CONDA_PREFIX=$CONDA_DIR/envs/cellvit_env

WORKDIR /

ENTRYPOINT ["/bin/bash"]

CMD ["-l"]