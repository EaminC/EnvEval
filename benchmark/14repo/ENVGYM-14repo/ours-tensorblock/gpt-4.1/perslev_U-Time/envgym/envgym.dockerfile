FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
        wget \
        git \
        build-essential \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libx11-dev \
        libtk8.6 \
        bzip2 \
        ca-certificates \
        sudo \
        locales \
        && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL=en_US.UTF-8

ENV CONDA_DIR=/opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

RUN conda update -n base -c defaults conda && \
    conda config --add channels conda-forge && \
    conda config --add channels defaults && \
    conda config --set channel_priority flexible

WORKDIR /root
RUN git clone https://github.com/perslev/U-Time.git
WORKDIR /root/U-Time

RUN set -e; \
    conda env create --name u-sleep --file environment.yaml > /tmp/conda_env_create.log 2>&1 || (cat /tmp/conda_env_create.log && exit 1)

RUN conda run -n u-sleep conda list

RUN echo "=== /root/U-Time/requirements.txt ===" && cat /root/U-Time/requirements.txt

RUN conda run -n u-sleep pip install --upgrade pip

RUN conda run -n u-sleep pip install "setuptools-git>=0.3" wheel

RUN bash -c '\
    touch /tmp/pip_individual_install.log; \
    while read req; do \
        if [ ! -z "$req" ] && [ "${req:0:1}" != "#" ]; then \
            echo "=== Installing: $req ===" | tee -a /tmp/pip_individual_install.log; \
            conda run -n u-sleep pip install --no-cache-dir "$req" >> /tmp/pip_individual_install.log 2>&1 || \
                (echo "=== pip install failed for: $req ===" && tail -n 40 /tmp/pip_individual_install.log && exit 1); \
        fi; \
    done < requirements.txt'

RUN echo "=== /tmp/pip_individual_install.log ===" && cat /tmp/pip_individual_install.log

RUN conda run -n u-sleep pip install --upgrade setuptools wheel setuptools-git

RUN ls -l README.md HISTORY.rst LICENSE.txt utime/version.py

RUN grep "install_requires" setup.py || true
RUN grep "setup_requires" setup.py || true

RUN conda run -n u-sleep python setup.py check > /tmp/pip_utime_check.log 2>&1 || (cat /tmp/pip_utime_check.log && exit 1)

# Diagnostic: Show version file before build
RUN echo "=== utime/version.py ===" && cat utime/version.py

# Diagnostic: Show MANIFEST.in
RUN echo "=== MANIFEST.in ===" && cat MANIFEST.in

# Diagnostic: Show current git HEAD and status
RUN git rev-parse HEAD
RUN git status

# Ensure .git exists and is readable
RUN test -d .git && echo ".git directory present" || (echo ".git directory missing" && exit 1)

# Show setup.py version string extraction for debug
RUN grep version setup.py || true

# Build wheel and capture log, show log immediately after
RUN conda run -n u-sleep python setup.py sdist bdist_wheel > /tmp/pip_utime_build.log 2>&1 || (echo "=== /tmp/pip_utime_build.log ===" && cat /tmp/pip_utime_build.log && exit 1)

RUN echo "=== /tmp/pip_utime_build.log ===" && cat /tmp/pip_utime_build.log || true

RUN echo "=== dist directory contents ===" && ls -l dist || true

RUN if ! ls dist/*.whl 1>/dev/null 2>&1; then echo "=== dist/*.whl missing ==="; cat /tmp/pip_utime_build.log; exit 1; fi

RUN conda run -n u-sleep pip install dist/*.whl > /tmp/pip_utime_install.log 2>&1 || (cat /tmp/pip_utime_install.log && exit 1)

RUN echo "=== /tmp/pip_utime_install.log ===" && cat /tmp/pip_utime_install.log || true

RUN conda run -n u-sleep python -c "import utime"

RUN conda run -n u-sleep ut --help || true

WORKDIR /root/U-Time

ENTRYPOINT ["/bin/bash"]