FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONIOENCODING=UTF-8 \
    PATH=/opt/conda/bin:$PATH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        locales \
        git \
        jq \
        wget \
        curl \
        lsof \
        rsync \
        build-essential \
        openssh-client \
        vim \
        netcat \
        && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean -afy

RUN /opt/conda/bin/conda info
RUN /opt/conda/bin/conda list

RUN /opt/conda/bin/conda config --add channels conda-forge

RUN /opt/conda/bin/conda update conda -y || true && /opt/conda/bin/conda clean -afy

# Removed: RUN /opt/conda/bin/conda update --all -y

RUN /opt/conda/bin/conda init bash

# Removed: RUN /opt/conda/bin/conda search python

RUN /opt/conda/bin/conda create -y -n node0 python=3.11.4

RUN /opt/conda/bin/conda env list && /opt/conda/bin/conda info --envs

RUN /opt/conda/bin/conda install -n node0 pip -y

WORKDIR /workspace

COPY . /workspace

RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda activate node0 && \
    python -m pip install --upgrade pip setuptools wheel && \
    pip install hatchling && \
    pip install 'hivemind @ git+https://github.com/learning-at-home/hivemind.git@4d5c41495be082490ea44cce4e9dd58f9926bb4e' && \
    pip install . && \
    python -m pip cache purge"

EXPOSE 49200

WORKDIR /

ENTRYPOINT ["/bin/bash"]