FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PATH="/root/.local/bin:${PATH}"
ENV UV_NATIVE_TLS=true
ENV RAY_DISABLE_DOCKER_CPU_WARNING=1
ENV OMP_NUM_THREADS=4
ENV BATCH_SIZE=1

RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN git clone https://github.com/NVIDIA-NeMo/Gym.git NeMo_Gym

WORKDIR /workspace/NeMo_Gym

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN echo '.venv/\nenv.yaml\n.env\n*.jsonl\ncache/\nresults/\n*.egg\nbuild/\ndist/\nlogs/\n__pycache__/\n*.pyc\n.coverage\n.pytest_cache/\n.mypy_cache/\n.ruff_cache/' > .gitignore

RUN uv venv --python 3.12

RUN . .venv/bin/activate && uv sync --extra dev --group docs

RUN mkdir -p logs

RUN echo '# Example env.yaml configuration\npolicy_base_url: "https://api.openai.com/v1"\npolicy_api_key: "YOUR_OPENAI_API_KEY"\npolicy_model_name: "gpt-3.5-turbo"' > env.yaml.example

RUN echo '{"responses_create_params":{"input":[{"role":"developer","content":"You are a helpful assistant."},{"role":"user","content":"What is the weather in Seattle?"}]}}' > weather_query.jsonl.example

RUN echo '#!/bin/bash\nsource /workspace/NeMo_Gym/.venv/bin/activate\nexec "$@"' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

RUN echo 'source /workspace/NeMo_Gym/.venv/bin/activate' >> /root/.bashrc

WORKDIR /workspace/NeMo_Gym

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]