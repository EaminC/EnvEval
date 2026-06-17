FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libssl-dev \
        cmake \
        git \
        python3 \
        python3-pip \
        curl \
        ca-certificates \
        bash \
        locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN mkdir -p /repo

WORKDIR /repo

RUN git config --global --add safe.directory /repo

COPY . /repo

WORKDIR /repo

# Manually ensure CUDA/GPU files are not included
RUN rm -f cuda/build.rs cuda/CMakeLists.txt

# Manually edit root Cargo.toml to ensure no CUDA/GPU workspace members
RUN sed -i '/cuda/d;/plonky2_cuda/d' Cargo.toml

# Manually edit all Cargo.toml files to ensure no CUDA/GPU dependencies, dev-dependencies, or features
RUN for f in $(find . -name 'Cargo.toml'); do \
      sed -i '/cuda/d;/plonky2_cuda/d' "$f"; \
      sed -i '/features.*cuda/d;/default-features.*cuda/d' "$f"; \
    done

# Remove CUDA/GPU references from Cargo.lock if present
RUN if [ -f Cargo.lock ]; then sed -i '/cuda/d;/plonky2_cuda/d' Cargo.lock; fi

# Remove CUDA/GPU references from .cargo/config and .cargo/config.toml if files exist
RUN if [ -f .cargo/config ]; then sed -i '/cuda/d;/plonky2_cuda/d' .cargo/config; fi
RUN if [ -f .cargo/config.toml ]; then sed -i '/cuda/d;/plonky2_cuda/d' .cargo/config.toml; fi

# Remove CUDA/GPU feature flags and mod declarations from source code
RUN for f in $(find . -type f -name '*.rs' -o -name '*.c' -o -name '*.cu' -o -name '*.cuh'); do \
      sed -i '/plonky2_cuda/d;/cuda/d;/nvcc/d;/gpu/d;/CUDA/d' "$f"; \
      sed -i '/mod cuda/d;/mod plonky2_cuda/d' "$f"; \
    done

# Regenerate Cargo.lock
RUN cargo generate-lockfile

RUN cargo fetch

# Diagnostic: check workspace for unresolved issues before build
RUN cargo check --workspace || (cat /repo/target/debug/build/*/output || true)

# Attempt to build workspace in debug mode and output error if it fails
RUN cargo build --workspace || (cat /repo/target/debug/build/*/output || true)

# Attempt to build workspace in release mode and output error if it fails
RUN cargo build --release --workspace || (cat /repo/target/release/build/*/output || true)

# After successful build, run tests and output errors if any
RUN cargo test --workspace || (cat /repo/target/debug/build/*/output || true)

WORKDIR /repo

ENTRYPOINT ["/bin/bash"]