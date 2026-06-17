FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc-10 g++-10 \
    clang-12 \
    cmake \
    git \
    curl \
    ca-certificates \
    python3 python3-pip \
    pkg-config \
    libssl-dev \
    libclang-dev \
    llvm-dev \
    libelf-dev \
    libdw-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable

ENV PATH="/root/.cargo/bin:${PATH}"

RUN rustc --version && cargo --version

WORKDIR /app

COPY . /app

RUN git submodule update --init --recursive

RUN rustup component add rustfmt clippy

RUN rustup target add x86_64-unknown-linux-gnu

RUN cargo clean

RUN cargo build --release --workspace --verbose

RUN mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DENABLE_CUDA=OFF && cmake --build . -- -j$(nproc)

WORKDIR /app

CMD ["/bin/bash"]