FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV RUST_VERSION=stable
ENV CMAKE_VERSION=3.28.1
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    git \
    curl \
    wget \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    valgrind \
    llvm \
    clang \
    lld \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh \
    && chmod +x cmake-${CMAKE_VERSION}-linux-x86_64.sh \
    && ./cmake-${CMAKE_VERSION}-linux-x86_64.sh --skip-license --prefix=/usr/local \
    && rm cmake-${CMAKE_VERSION}-linux-x86_64.sh

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION} \
    && rustup component add rust-src \
    && rustup component add rustfmt \
    && rustup component add clippy

WORKDIR /workspace

RUN git clone https://github.com/0xPolygonZero/plonky2.git /workspace

RUN mkdir -p .cargo scripts docker benchmarks

COPY <<'EOF' .env
RUST_BACKTRACE=1
RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=thin"
CXXFLAGS="-O3 -march=native"
CC=gcc
CXX=g++
EOF

COPY <<'EOF' .cargo/config.toml
[build]
target-cpu = "native"
rustflags = ["-C", "opt-level=3", "-C", "lto=thin", "-C", "codegen-units=1"]

[profile.release]
opt-level = 3
lto = "thin"
codegen-units = 1
panic = "abort"
debug = true

[profile.bench]
opt-level = 3
lto = "thin"
codegen-units = 1
debug = true
EOF

COPY <<'EOF' .gitignore
/target
**/*.rs.bk
Cargo.lock
.env.local
*.log
.DS_Store
/tmp
/benchmarks/results
/docker/volumes
EOF

COPY <<'EOF' scripts/setup.sh
#!/bin/bash
set -e
echo "Setting up plonky2 environment..."
source .env
cargo --version
rustc --version
cmake --version
echo "Building workspace..."
cargo build --workspace
echo "Running tests..."
cargo test --workspace
echo "Setup complete!"
EOF

COPY <<'EOF' scripts/verify-deps.sh
#!/bin/bash
set -e
echo "Verifying dependencies..."
cargo tree --workspace
cargo check --workspace --all-features
echo "Dependencies verified!"
EOF

COPY <<'EOF' scripts/benchmark-plonky2.sh
#!/bin/bash
set -e
echo "Running plonky2 benchmarks..."
cargo bench -p plonky2 --bench field_arithmetic
cargo bench -p plonky2 --bench ffts
cargo bench -p plonky2 --bench hashing
cargo bench -p plonky2 --bench merkle
cargo bench -p plonky2 --bench transpose
cargo bench -p plonky2 --bench reverse_index_bits
EOF

COPY <<'EOF' scripts/benchmark-evm.sh
#!/bin/bash
set -e
echo "Running EVM benchmarks..."
cargo bench -p plonky2_evm --bench stack_manipulation
cargo bench -p plonky2_evm
EOF

COPY <<'EOF' scripts/benchmark-field.sh
#!/bin/bash
set -e
echo "Running field benchmarks..."
cargo bench -p plonky2_field
EOF

COPY <<'EOF' scripts/benchmark-insertion.sh
#!/bin/bash
set -e
echo "Running insertion benchmarks..."
cargo bench -p plonky2_insertion
EOF

COPY <<'EOF' scripts/benchmark-starky.sh
#!/bin/bash
set -e
echo "Running STARK benchmarks..."
cargo bench -p starky
EOF

COPY <<'EOF' scripts/benchmark-system-zero.sh
#!/bin/bash
set -e
echo "Running system_zero benchmarks..."
cargo bench -p system_zero --bench lookup_permuted_cols
cargo bench -p system_zero
EOF

COPY <<'EOF' scripts/benchmark-u32.sh
#!/bin/bash
set -e
echo "Running u32 benchmarks..."
cargo bench -p plonky2_u32
EOF

COPY <<'EOF' scripts/benchmark-util.sh
#!/bin/bash
set -e
echo "Running util benchmarks..."
cargo bench -p plonky2_util
EOF

COPY <<'EOF' scripts/benchmark-waksman.sh
#!/bin/bash
set -e
echo "Running waksman benchmarks..."
cargo bench -p plonky2_waksman
EOF

COPY <<'EOF' docker/docker-compose.yml
version: '3.8'
services:
  plonky2-cpu:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    volumes:
      - ../:/workspace
    environment:
      - RUST_BACKTRACE=1
    command: /bin/bash
EOF

COPY <<'EOF' benchmarks/config.toml
[benchmark]
iterations = 100
warmup_iterations = 10
sample_size = 50

[cpu]
threads = 8
affinity = true
EOF

RUN chmod +x scripts/*.sh

RUN if [ -f "Cargo.toml" ]; then \
        echo "Found workspace Cargo.toml" && \
        cargo fetch || echo "cargo fetch failed, continuing"; \
    else \
        echo "No Cargo.toml found at workspace root"; \
    fi

RUN if [ -f "Cargo.toml" ]; then \
        echo "Building workspace..." && \
        cargo build --workspace --release || echo "Build failed, continuing"; \
    else \
        echo "Cannot build - no Cargo.toml found"; \
    fi

ENV RUST_BACKTRACE=1
ENV RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=thin"

CMD ["/bin/bash"]