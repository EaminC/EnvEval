FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV TAO_WORKSPACE=/home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514/tao_workspace
ENV TAO_API_BASE_URL=http://localhost:8090
ENV DOCKER_NETWORK=tao_default
ENV PYTHON_VERSION=3.8
ENV DEPLOYMENT_MODE=DEV
ENV AWS_ACCESS_KEY_ID=seaweedfs
ENV AWS_SECRET_ACCESS_KEY=seaweedfs123
ENV SEAWEED_ENDPOINT=http://localhost:8333
ENV TAO_STORAGE_BUCKET=tao-storage
ENV PATH="/home/cc/ngc-cli:${PATH}"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    software-properties-common \
    python3.8 \
    python3.8-venv \
    python3.8-dev \
    python3-pip \
    wget \
    unzip \
    gzip \
    jq \
    sed \
    coreutils \
    curl \
    git \
    awscli \
    gettext-base \
    openssh-client \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -u 1000 cc && \
    echo "cc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER cc
WORKDIR /home/cc

RUN python3.8 -m pip install --upgrade pip && \
    pip install jupyter notebook ipykernel nvidia-tao

RUN mkdir -p /home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514

WORKDIR /home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514

RUN git config --global user.email "cc@example.com" && \
    git config --global user.name "cc" && \
    git config --global http.postBuffer 524288000 && \
    git config --global http.timeout 600 && \
    git config --global core.compression 0 && \
    git config --global http.lowSpeedLimit 1000 && \
    git config --global http.lowSpeedTime 600

RUN for i in 1 2 3 4 5; do \
        echo "Attempt $i: Cloning tao_tutorials..." && \
        git clone --depth 1 https://github.com/NVIDIA/tao_tutorials.git && \
        echo "Successfully cloned tao_tutorials" && \
        break || \
        (echo "Failed attempt $i, waiting..." && rm -rf tao_tutorials && sleep $((i * 10))); \
    done && \
    test -d tao_tutorials || (echo "Failed to clone tao_tutorials after 5 attempts" && exit 1)

RUN ls -la && \
    test -d tao_tutorials && echo "✓ tao_tutorials directory exists" || echo "✗ tao_tutorials directory missing"

RUN mkdir -p ${TAO_WORKSPACE}/data && \
    mkdir -p ${TAO_WORKSPACE}/models && \
    mkdir -p ${TAO_WORKSPACE}/logs && \
    mkdir -p ${TAO_WORKSPACE}/airgapped-models && \
    mkdir -p ${TAO_WORKSPACE}/saved-docker-images && \
    mkdir -p ${TAO_WORKSPACE}/setup/tao-docker-compose/nginx_sites && \
    mkdir -p ${TAO_WORKSPACE}/shared-storage/models && \
    mkdir -p ${TAO_WORKSPACE}/notebooks/tao_launcher_starter_kit/deps && \
    touch ${TAO_WORKSPACE}/logs/.gitkeep && \
    touch ${TAO_WORKSPACE}/data/.gitkeep && \
    touch ${TAO_WORKSPACE}/models/.gitkeep && \
    touch ${TAO_WORKSPACE}/airgapped-models/.gitkeep && \
    touch ${TAO_WORKSPACE}/saved-docker-images/.gitkeep && \
    touch ${TAO_WORKSPACE}/shared-storage/models/.gitkeep

RUN cp -r tao_tutorials/setup/tao-docker-compose/* ${TAO_WORKSPACE}/setup/tao-docker-compose/ && \
    cp -r tao_tutorials/notebooks/* ${TAO_WORKSPACE}/notebooks/ && \
    cp tao_tutorials/setup/quickstart_launcher.sh ${TAO_WORKSPACE}/setup/ && \
    chmod +x ${TAO_WORKSPACE}/setup/quickstart_launcher.sh

RUN cat > ${TAO_WORKSPACE}/notebooks/tao_launcher_starter_kit/deps/requirements-pip.txt <<EOF
numpy<2
opencv-python<=4.10.0.84
pillow<=10.4.0
matplotlib<=3.8.2
scipy<=1.11.4
h5py<=3.12.1
joblib<=1.3.2
pycocotools>=2.0.2,<=2.0.7
wandb<=0.16.3
urllib3>=1.26.15,<2.0.0
EOF

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/secrets.json <<EOF
{
  "ngc_api_key": "",
  "ptm_api_key": ""
}
EOF

RUN chmod 600 ${TAO_WORKSPACE}/setup/tao-docker-compose/secrets.json

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/config.env <<'EOF'
# TAO Docker Compose Configuration - CPU Only Mode
# =================================================

# Deployment Settings
AIRGAPPED_MODE=true
DEPLOYMENT_MODE=DEV
USE_ADMIN_KEY=false
PTM_PULL=false

# Python Version Settings
PYTHON_VERSION=3.8
PYTHON_BASE_PATH=/opt/venv/cosmos_rl/lib/python

# Image Settings (CPU-only versions if available)
IMAGE_TAO_API=nvcr.io/nvidia/tao/tao-toolkit:6.26.3-cosmos-rl
IMAGE_TAO_PYTORCH=nvcr.io/nvidia/tao/tao-toolkit:6.26.3-pyt
IMAGE_TAO_DEPLOY=nvcr.io/nvidia/tao/tao-toolkit:6.26.3-deploy
IMAGE_VILA=nvcr.io/ea-tlt/tao_ea/vila_fine_tuning_inf:latest
IMAGE_TAO_DS=nvcr.io/nvidia/tao/tao-toolkit:6.26.3-data-services
IMAGE_COSMOS_RL=nvcr.io/nvidia/tao/tao-toolkit:6.26.3-cosmos-rl

# CPU Settings (No GPU)
NUM_GPU_PER_NODE=0
MAX_GPU_PER_USER_REALTIME_INFER=0

# Network Settings
CALLBACK_UUID=5f931ba3-d448-54fe-955c-a63795b01c98
HOSTBASEURL=http://tao_api_app:8000
NGINX_HTTP_PORT=8090
NGINX_HTTPS_PORT=8443
DOCKER_NETWORK=tao_default

# SeaweedFS Settings (local storage)
SEAWEEDFS_ENABLED=true
SEAWEEDFS_REPLICATION=000
SEAWEEDFS_FILER_PORT=8888
SEAWEEDFS_S3_PORT=8333
SEAWEEDFS_VOLUME_PORT=8080
SEAWEEDFS_MASTER_PORT=9333
LOCAL_MODEL_REGISTRY=/shared-storage/models
SEAWEEDFS_ACCESS_KEY=seaweedfs
SEAWEEDFS_SECRET_KEY=seaweedfs123
AWS_ACCESS_KEY_ID=seaweedfs
AWS_SECRET_ACCESS_KEY=seaweedfs123
SEAWEED_ENDPOINT=http://localhost:8333
TAO_STORAGE_BUCKET=tao-storage

# General TAO settings
LOG_LEVEL=DEBUG
EOF

RUN cp ${TAO_WORKSPACE}/setup/tao-docker-compose/config.env ${TAO_WORKSPACE}/setup/tao-docker-compose/config.env.example

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/s3-config.json <<EOF
{
  "identities": [
    {
      "name": "anonymous",
      "actions": [
        "Read:bucket1"
      ]
    },
    {
      "name": "seaweedfs-admin",
      "credentials": [
        {
          "accessKey": "seaweedfs",
          "secretKey": "seaweedfs123"
        }
      ],
      "actions": [
        "Admin",
        "Read",
        "ReadAcp",
        "List",
        "Tagging",
        "Write",
        "WriteAcp"
      ]
    }
  ]
}
EOF

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;

    # Include individual site configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/nginx_sites/default.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    resolver 127.0.0.11 ipv6=off valid=10s;
    location /swagger {
        proxy_pass http://tao_api_app:8000/swagger;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /openapi.json {
        proxy_pass http://tao_api_app:8000/openapi.json;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://tao_api_app:8000/api/v1/health/liveness;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/ {
        proxy_pass http://tao_api_app:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass_request_headers on;

        # Extended timeouts for inference microservice operations
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        send_timeout 300s;
    }

    ${SEAWEEDFS_CONFIG}
}
EOF

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/save-docker-images.sh <<'EOF'
#!/usr/bin/env bash
# TAO Docker Image Saver (bundled, JSON manifest, no meta files)
# - Saves each image as .tar in OUTPUT_DIR
# - Writes OUTPUT_DIR/manifest.json mapping tar -> exact image ref
# - Creates one .tar.gz bundle containing OUTPUT_DIR contents (tars + manifest.json)

# ---------- Safe reversible filename helpers ----------
sanitize_component() { sed -E 's/[^A-Za-z0-9._-]+/-/g' <<<"$1"; }

encode_image_ref() {
  # Input ref: registry/path1/path2/name[:tag]  OR  registry/...@sha256:HEX
  local ref="$1"
  local registry="${ref%%/*}"
  local rest="${ref#*/}"
  if [[ "$ref" == "$rest" ]]; then registry="docker.io"; rest="$ref"; fi

  if [[ "$rest" == *"@sha256:"* ]]; then
    local repo="${rest%@sha256:*}"; repo="${repo%/}"
    local hex="${rest#*@sha256:}"
    IFS='/' read -r -a segs <<<"$repo"
    local encoded; encoded="$(sanitize_component "$registry")"
    for s in "${segs[@]}"; do encoded+="__$(sanitize_component "$s")"; done
    echo "${encoded}__d-sha256-$(sanitize_component "$hex")"
    return
  fi

  local repo tag=""
  if [[ "${rest#*/}" == *:* ]]; then
    repo="${rest%:*}"; tag="${rest##*:}"
  else
    repo="$rest"
  fi

  IFS='/' read -r -a segs <<<"$repo"
  local encoded; encoded="$(sanitize_component "$registry")"
  for s in "${segs[@]}"; do encoded+="__$(sanitize_component "$s")"; done

  if [[ -z "$tag" ]]; then
    if docker image inspect "$ref" >/dev/null 2>&1; then
      local first_tag
      first_tag="$(docker image inspect "$ref" --format '{{(index .RepoTags 0)}}' 2>/dev/null || true)"
      [[ -n "$first_tag" && "$first_tag" == *:* ]] && tag="${first_tag##*:}" || tag="latest"
    else
      tag="latest"
    fi
  fi
  echo "${encoded}__t-$(sanitize_component "$tag")"
}

# ---------- Usage ----------
show_usage() {
  cat <<USAGE
Usage: $0 [OPTIONS]

Options:
  --config=FILE        Config file (default: config.env)
  --output-dir=DIR     Staging folder for per-image .tar (default: ./saved-docker-images)
  --bundle=FILE        Final bundle .tar.gz (default: ./saved-docker-images-bundle.tar.gz)
  --pull               Pull all images (default: auto pull missing)
  --no-pull            Do not pull (only save local)
  --force              Overwrite existing .tar files
  --help               Show help
USAGE
}

# ---------- Defaults ----------
CONFIG_FILE="config.env"
OUTPUT_DIR="./saved-docker-images"
BUNDLE_FILE="./saved-docker-images-bundle.tar.gz"
PULL_IMAGES="auto"  # auto | force | never
FORCE_SAVE=false

# ---------- Parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config=*)     CONFIG_FILE="${1#*=}"; shift ;;
    --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
    --bundle=*)     BUNDLE_FILE="${1#*=}"; shift ;;
    --pull)         PULL_IMAGES="force"; shift ;;
    --no-pull)      PULL_IMAGES="never"; shift ;;
    --force)        FORCE_SAVE=true; shift ;;
    -h|--help)      show_usage; exit 0 ;;
    *) echo "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

# ---------- Preflight ----------
[[ -f "$CONFIG_FILE" ]] || { echo "Error: Config '$CONFIG_FILE' not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker not in PATH"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Error: Docker daemon not running"; exit 1; }

echo "TAO Docker Image Saver (Bundled, JSON manifest, no meta files)"
echo "=============================================================="
echo "Config:      $CONFIG_FILE"
echo "Output dir:  $OUTPUT_DIR"
echo "Bundle:      $BUNDLE_FILE"
echo "Pull mode:   $PULL_IMAGES"
echo "Force save:  $FORCE_SAVE"
echo ""

mkdir -p "$OUTPUT_DIR"

echo "Loading $CONFIG_FILE ..."
set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

TAO_IMAGES=( "IMAGE_TAO_API" "IMAGE_TAO_PYTORCH" "IMAGE_TAO_DEPLOY" "IMAGE_VILA" "IMAGE_TAO_DS" )

available=()
for v in "${TAO_IMAGES[@]}"; do
  [[ -n "${!v-}" ]] && available+=("${!v}")
done

echo "Images to process (${#available[@]}):"
printf '  %s\n' "${available[@]}"
echo ""

saved_count=0 skipped_count=0 failed_count=0 processed=0

# Start JSON manifest
manifest_json="$OUTPUT_DIR/manifest.json"
echo "[" > "$manifest_json"
first_entry=true

for image_ref in "${available[@]}"; do
  ((processed++))
  echo "[$processed/${#available[@]}] $image_ref"

  local_exists=false
  if docker image inspect "$image_ref" >/dev/null 2>&1; then
    local_exists=true; echo "  Status: Found locally"
  else
    echo "  Status: Not local"
  fi

  should_pull=false
  case "$PULL_IMAGES" in
    force) should_pull=true ;;
    auto)  [[ $local_exists == false ]] && should_pull=true ;;
    never) ;;
  esac

  if $should_pull; then
    echo "  Pulling..."
    if ! docker pull "$image_ref"; then
      echo "  Pull failed"; ((failed_count++)); echo ""; continue
    fi
    local_exists=true
  fi

  if [[ $local_exists == false ]]; then
    echo "  Skipping (not local, pull disabled)"; ((skipped_count++)); echo ""; continue
  fi

  base="$(encode_image_ref "$image_ref")"
  out_tar="$OUTPUT_DIR/${base}.tar"

  if [[ -f "$out_tar" && $FORCE_SAVE == false ]]; then
    echo "  Exists, skip save: $(basename "$out_tar")"
  else
    echo "  Saving -> $out_tar"
    if ! docker save -o "$out_tar" "$image_ref"; then
      echo "  Save failed"; ((failed_count++)); echo ""; continue
    fi
  fi

  # Append to manifest.json
  # Fields: file (tar name), ref (image reference)
  if $first_entry; then first_entry=false; else echo "," >> "$manifest_json"; fi
  printf '  { "file": "%s", "ref": "%s" }' "${base}.tar" "$image_ref" >> "$manifest_json"

  ((saved_count++))
  echo ""
done

# Close JSON manifest
echo "" >> "$manifest_json"
echo "]" >> "$manifest_json"

echo "================================"
echo "Saved:   $saved_count"
echo "Skipped: $skipped_count"
echo "Failed:  $failed_count"
echo "Manifest: $manifest_json"
echo ""

# Create bundle
if [[ $saved_count -gt 0 ]]; then
  echo "Creating bundle: $BUNDLE_FILE"
  tar -czf "$BUNDLE_FILE" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")"
  echo "Bundle created successfully"
else
  echo "No images saved, skipping bundle creation"
fi
EOF

RUN chmod +x ${TAO_WORKSPACE}/setup/tao-docker-compose/save-docker-images.sh

RUN cat > ${TAO_WORKSPACE}/setup/tao-docker-compose/cleanup-seaweed-storage.sh <<'EOF'
#!/usr/bin/env bash
# Clean up SeaweedFS S3 storage (tao-storage bucket).
# Deletes all objects (datasets, shared-storage/models, job outputs). Does NOT clear workspaces:
# workspace/experiment/job metadata live in MongoDB. To clear those run: ./run.sh clear-mongo

set -e

SEAWEED_ENDPOINT="${SEAWEED_ENDPOINT:-http://localhost:8333}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-seaweedfs}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-seaweedfs123}"
BUCKET="${TAO_STORAGE_BUCKET:-tao-storage}"

echo "Seaweed cleanup: endpoint=$SEAWEED_ENDPOINT bucket=$BUCKET"
if ! command -v aws &>/dev/null; then
    echo "Error: aws CLI not found. Install it (e.g. pip install awscli) and retry."
    exit 1
fi

echo "Listing current objects..."
if ! AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    aws s3 ls "s3://${BUCKET}/" --endpoint-url "$SEAWEED_ENDPOINT" --recursive 2>/dev/null | head -50; then
    echo "Bucket may be empty or unreachable. Attempting delete anyway."
fi

echo "Deleting all objects in s3://${BUCKET}/ ..."
AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    aws s3 rm "s3://${BUCKET}/" --endpoint-url "$SEAWEED_ENDPOINT" --recursive

echo "Seaweed storage cleanup completed. Re-upload data and run load_airgapped_model as needed."
echo "To clear older workspaces/experiments (stored in MongoDB), run: ./run.sh clear-mongo"
EOF

RUN chmod +x ${TAO_WORKSPACE}/setup/tao-docker-compose/cleanup-seaweed-storage.sh

RUN cd ${TAO_WORKSPACE}/setup/tao-docker-compose && \
    chmod +x run.sh save-docker-images.sh load-docker-images.sh cleanup-seaweed-storage.sh

RUN wget --content-disposition https://ngc.nvidia.com/downloads/ngccli_linux.zip -O /home/cc/ngccli_linux.zip && \
    cd /home/cc && unzip ngccli_linux.zip && \
    chmod u+x ngc-cli/ngc && \
    rm -rf /home/cc/ngccli_linux.zip /home/cc/ngc-cli.md5

RUN python3.8 -m venv ${TAO_WORKSPACE}/tao_venv

RUN . ${TAO_WORKSPACE}/tao_venv/bin/activate && \
    pip install nvidia-tao && \
    pip install -r ${TAO_WORKSPACE}/notebooks/tao_launcher_starter_kit/deps/requirements-pip.txt

RUN ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" && \
    touch ~/.ssh/known_hosts

RUN cat > ${TAO_WORKSPACE}/verify_cpu_installation.py <<'EOF'
#!/usr/bin/env python3
import sys
import subprocess
import json

def check_docker():
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        print(f"✓ Docker: {result.stdout.strip()}")
        return True
    except:
        print("✗ Docker not found")
        return False

def check_python():
    print(f"✓ Python: {sys.version}")
    return True

def check_services():
    try:
        result = subprocess.run(['docker', 'ps', '--format', 'table {{.Names}}'], capture_output=True, text=True)
        services = result.stdout.strip().split('\n')[1:]
        print(f"✓ Running services: {len(services)}")
        for service in services:
            print(f"  - {service}")
        return True
    except:
        print("✗ Could not check services")
        return False

def main():
    print("TAO CPU-Only Environment Verification")
    print("=" * 40)
    
    checks = [
        check_docker(),
        check_python(),
        check_services()
    ]
    
    if all(checks):
        print("\n✓ All checks passed!")
        print("\nNote: TAO training/inference containers require GPU and will not run in CPU-only mode.")
        print("This setup is suitable for:")
        print("- Data preparation and management")
        print("- SeaweedFS storage operations")
        print("- MongoDB operations")
        print("- NGINX proxy testing")
        print("- Environment preparation for later GPU deployment")
    else:
        print("\n✗ Some checks failed. Please review the setup.")

if __name__ == "__main__":
    main()
EOF

RUN chmod +x ${TAO_WORKSPACE}/verify_cpu_installation.py

RUN echo 'export TAO_WORKSPACE=/home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514/tao_workspace' >> ~/.bashrc && \
    echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc && \
    echo 'export TAO_API_BASE_URL=http://localhost:8090' >> ~/.bashrc && \
    echo 'export DOCKER_NETWORK=tao_default' >> ~/.bashrc && \
    echo 'export PYTHON_VERSION=3.8' >> ~/.bashrc && \
    echo 'export DEPLOYMENT_MODE=DEV' >> ~/.bashrc && \
    echo 'export AWS_ACCESS_KEY_ID=seaweedfs' >> ~/.bashrc && \
    echo 'export AWS_SECRET_ACCESS_KEY=seaweedfs123' >> ~/.bashrc && \
    echo 'export SEAWEED_ENDPOINT=http://localhost:8333' >> ~/.bashrc && \
    echo 'export TAO_STORAGE_BUCKET=tao-storage' >> ~/.bashrc && \
    echo 'export PATH="/home/cc/ngc-cli:$PATH"' >> ~/.bashrc && \
    echo 'source ${TAO_WORKSPACE}/tao_venv/bin/activate' >> ~/.bashrc

RUN cat > ${TAO_WORKSPACE}/.env <<EOF
TAO_WORKSPACE=/home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514/tao_workspace
TAO_API_BASE_URL=http://localhost:8090
DOCKER_NETWORK=tao_default
PYTHON_VERSION=3.8
DEPLOYMENT_MODE=DEV
AWS_ACCESS_KEY_ID=seaweedfs
AWS_SECRET_ACCESS_KEY=seaweedfs123
SEAWEED_ENDPOINT=http://localhost:8333
TAO_STORAGE_BUCKET=tao-storage
EOF

RUN cat > ${TAO_WORKSPACE}/requirements.txt <<EOF
numpy<2
opencv-python<=4.10.0.84
pillow<=10.4.0
matplotlib<=3.8.2
scipy<=1.11.4
h5py<=3.12.1
joblib<=1.3.2
pycocotools>=2.0.2,<=2.0.7
wandb<=0.16.3
urllib3>=1.26.15,<2.0.0
jupyter
notebook
ipykernel
nvidia-tao
EOF

RUN cat > ${TAO_WORKSPACE}/verify_installation.py <<'EOF'
#!/usr/bin/env python3
import sys
import os
import subprocess

def verify_installation():
    print("Verifying TAO installation...")
    checks = []
    
    # Check Python version
    print(f"Python version: {sys.version}")
    checks.append(sys.version_info >= (3, 8))
    
    # Check TAO workspace
    workspace = os.environ.get('TAO_WORKSPACE')
    print(f"TAO workspace: {workspace}")
    checks.append(workspace is not None and os.path.exists(workspace))
    
    # Check TAO CLI
    try:
        result = subprocess.run(['tao', '--help'], capture_output=True, text=True)
        print("TAO CLI: Available")
        checks.append(result.returncode == 0)
    except:
        print("TAO CLI: Not found")
        checks.append(False)
    
    # Check Docker
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        print(f"Docker: {result.stdout.strip()}")
        checks.append(result.returncode == 0)
    except:
        print("Docker: Not found")
        checks.append(False)
    
    if all(checks):
        print("\nAll checks passed!")
    else:
        print("\nSome checks failed. Please review the installation.")
    
    return all(checks)

if __name__ == "__main__":
    verify_installation()
EOF

RUN chmod +x ${TAO_WORKSPACE}/verify_installation.py

RUN touch ${TAO_WORKSPACE}/.ngc_api_key ${TAO_WORKSPACE}/.ptm_api_key && \
    chmod 600 ${TAO_WORKSPACE}/.ngc_api_key ${TAO_WORKSPACE}/.ptm_api_key

RUN mkdir -p ~/.docker && \
    echo '{}' > ~/.docker/config.json

WORKDIR /home/cc/EnvGym/data/20260501_233214_anthropic_claude-opus-4-20250514/tao_tutorials

CMD ["/bin/bash"]