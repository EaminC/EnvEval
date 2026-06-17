FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    xvfb \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglu1-mesa \
    libxi6 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xfixes0 \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh

ENV PATH="/opt/conda/bin:$PATH"

RUN /opt/conda/bin/conda create -n py310 python=3.10 pip -y

RUN echo "conda activate py310" >> ~/.bashrc

ENV PATH="/opt/conda/envs/py310/bin:$PATH"

WORKDIR /workspace/Kilosort4

COPY . .

RUN /opt/conda/envs/py310/bin/pip install --upgrade pip setuptools wheel && \
    /opt/conda/envs/py310/bin/pip install setuptools-scm tox tox-gh-actions twine

RUN if [ ! -d ".git" ]; then \
        git init && \
        git config user.email "docker@example.com" && \
        git config user.name "Docker User" && \
        git add . && \
        git commit -m "Initial setup"; \
    fi

RUN /opt/conda/envs/py310/bin/pip install torch==1.13.1+cpu -f https://download.pytorch.org/whl/torch_stable.html

RUN /opt/conda/envs/py310/bin/pip install numpy>=1.20.0 scipy scikit-learn tqdm numba faiss-cpu && \
    /opt/conda/envs/py310/bin/pip install pytest pytest-cov pytest-xvfb py codecov && \
    /opt/conda/envs/py310/bin/pip install pyqtgraph>=0.13.0 qtpy PyQt6 PyQt6-sip matplotlib

RUN /opt/conda/envs/py310/bin/pip install -e . && \
    /opt/conda/envs/py310/bin/pip install sphinx>=3.0 sphinxcontrib-apidoc nbsphinx myst_parser sphinx_rtd_theme

ENV DISPLAY=:99
RUN Xvfb :99 -screen 0 1024x768x24 > /dev/null 2>&1 &

WORKDIR /workspace/Kilosort4

CMD ["/bin/bash"]