FROM python:3.10-slim

WORKDIR /workspace

# Install essential system dependencies only
RUN apt-get update && apt-get install -y \
    git \
    git-lfs \
    build-essential \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Configure git LFS
RUN git lfs install

# Clone repository
RUN git clone https://github.com/nyu-systems/CLM-GS.git /workspace/CLM-GS

WORKDIR /workspace/CLM-GS

# Upgrade pip, setuptools, and wheel
RUN pip install --upgrade pip setuptools wheel

# Install typing-extensions first
RUN pip install --no-cache-dir typing-extensions>=4.10.0

# Install PyTorch CPU version
RUN pip install --no-cache-dir torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cpu

# Install additional Python packages
RUN pip install --no-cache-dir \
    tqdm \
    plyfile \
    psutil \
    numba \
    opencv-python \
    scipy \
    matplotlib \
    pandas \
    imageio \
    imageio-ffmpeg \
    requests \
    tabulate \
    black

# Create environment variables file
RUN echo 'export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True' > /workspace/CLM-GS/environment_vars.sh && \
    echo 'export OMP_NUM_THREADS=8' >> /workspace/CLM-GS/environment_vars.sh && \
    echo 'export MKL_NUM_THREADS=8' >> /workspace/CLM-GS/environment_vars.sh && \
    echo 'export NUMEXPR_NUM_THREADS=8' >> /workspace/CLM-GS/environment_vars.sh

# Set environment variables
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
ENV OMP_NUM_THREADS=8
ENV MKL_NUM_THREADS=8
ENV NUMEXPR_NUM_THREADS=8

# Create test scripts
RUN echo '# Test script to verify CPU-only environment setup\n\
import torch\n\
import sys\n\
\n\
print(f"PyTorch version: {torch.__version__}")\n\
print(f"CUDA available: {torch.cuda.is_available()}")\n\
print(f"CPU threads: {torch.get_num_threads()}")\n\
print(f"Python version: {sys.version}")\n\
\n\
# Test basic tensor operations\n\
try:\n\
    cpu_tensor = torch.randn(1000, 1000)\n\
    result = torch.matmul(cpu_tensor, cpu_tensor.T)\n\
    print("✓ CPU tensor operations working")\n\
except Exception as e:\n\
    print(f"✗ CPU tensor operations failed: {e}")' > /workspace/CLM-GS/test_environment_cpu.py

RUN echo '# Test script to verify submodule functionality (CPU mode)\n\
import os\n\
import subprocess\n\
\n\
submodules = {\n\
    "cpu-adam": "git@github.com:TarzanZhao/cpu-adam.git",\n\
    "fast-tsp": "git@github.com:TarzanZhao/fast-tsp.git",\n\
    "simple-knn": "https://gitlab.inria.fr/simple-knn.git",\n\
    "gsplat": "https://github.com/nerfstudio-project/gsplat.git",\n\
    "clm_kernels": "git@github.com:nyu-systems/clm_kernels.git"\n\
}\n\
\n\
for name, url in submodules.items():\n\
    path = f"submodules/{name}"\n\
    if os.path.exists(path):\n\
        print(f"✓ {name} exists at {path}")\n\
        if name in ["gsplat", "clm_kernels", "simple-knn"]:\n\
            print(f"  ⚠️  {name} requires CUDA - will not be functional in CPU-only mode")\n\
    else:\n\
        print(f"✗ {name} missing at {path}")' > /workspace/CLM-GS/test_submodules_cpu.py

RUN echo '# Test script to identify CPU-only limitations\n\
import torch\n\
\n\
print("=== CPU-ONLY ENVIRONMENT LIMITATIONS ===")\n\
print("\\n1. CUDA-dependent features NOT available:")\n\
print("   - gsplat rendering kernels (requires CUDA)")\n\
print("   - CLM offload mode (requires CUDA DMA)")\n\
print("   - GPU acceleration for training")\n\
print("   - simple-knn CUDA kernels")\n\
print("   - Fast rendering operations")\n\
\n\
print("\\n2. Available features in CPU mode:")\n\
print("   - Dataset loading and preprocessing")\n\
print("   - Basic tensor operations")\n\
print("   - CPU-based Adam optimizer")\n\
print("   - Model checkpointing")\n\
print("   - Visualization utilities")\n\
\n\
print("\\n3. Performance expectations:")\n\
print("   - Training will be significantly slower")\n\
print("   - Limited to small-scale experiments")\n\
print("   - Memory usage will be higher")' > /workspace/CLM-GS/test_cpu_limitations.py

RUN echo '# Test script to verify CPU memory capabilities\n\
import psutil\n\
import torch\n\
\n\
# Get system memory info\n\
memory = psutil.virtual_memory()\n\
print(f"Total RAM: {memory.total / (1024**3):.2f} GB")\n\
print(f"Available RAM: {memory.available / (1024**3):.2f} GB")\n\
print(f"Used RAM: {memory.used / (1024**3):.2f} GB ({memory.percent}%)")\n\
\n\
# Test large tensor allocation\n\
try:\n\
    size_gb = 1\n\
    elements = int(size_gb * 1024**3 / 4)  # float32 = 4 bytes\n\
    tensor = torch.randn(elements)\n\
    print(f"\\n✓ Successfully allocated {size_gb} GB tensor")\n\
    del tensor\n\
except Exception as e:\n\
    print(f"\\n✗ Failed to allocate {size_gb} GB tensor: {e}")' > /workspace/CLM-GS/test_cpu_memory.py

# Create datasets directory
RUN mkdir -p /workspace/CLM-GS/datasets

WORKDIR /workspace/CLM-GS

CMD ["/bin/bash"]