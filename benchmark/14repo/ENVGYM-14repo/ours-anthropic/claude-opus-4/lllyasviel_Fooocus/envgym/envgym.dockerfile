FROM python:3.10

WORKDIR /app

COPY . .

RUN apt-get update || true && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    build-essential \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/* || true

RUN python3.10 -m venv venv

ENV PATH="/app/venv/bin:$PATH"

RUN pip install pip==23.0

RUN pip install packaging

RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

RUN pip install torchsde==0.2.6 || pip install torchsde==0.2.5 || true

RUN pip install -r requirements_versions.txt || true

RUN mkdir -p models/checkpoints \
    models/loras \
    models/embeddings \
    models/vae_approx \
    models/upscale_models \
    models/inpaint \
    models/controlnet \
    models/clip_vision \
    models/prompt_expansion/fooocus_expansion \
    outputs \
    input \
    cache \
    log \
    config_states

RUN if [ -f auth-example.json ]; then cp auth-example.json auth.json; fi

ENV PYTHONUNBUFFERED=1

EXPOSE 7860

ENTRYPOINT ["/bin/bash"]