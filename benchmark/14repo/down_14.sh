#!/usr/bin/env bash
#
# Clone the 14 source repos used by the new EnvEval rubrics into ../data/.
# This is the 14-repo equivalent of benchmark/down_all.sh.
#
# Run from: benchmark/14repo/
# Idempotent: skips repos already present in ../data/.
#
# Notes:
#  - The repo dir name in ../data/ MUST match the canonical org_repo name
#    used by the rubric, because DockerfileEvaluator looks up data/<repo>/
#    by exactly that name (which it gets from --repo).
#  - All 14 are public repos.
#  - tao_tutorials is large (~1 GB); SVRTK and CellViT++ are also chunky.

set -euo pipefail

# Resolve data dir relative to this script (so the script works from anywhere).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DATA_DIR:-${SCRIPT_DIR}/../data}"

mkdir -p "${DATA_DIR}"

# canonical_name|upstream_url
repos=(
  "TIO-IKIM_CellViT-Inference|https://github.com/TIO-IKIM/CellViT-Inference"
  "TIO-IKIM_CellViT-plus-plus|https://github.com/TIO-IKIM/CellViT-plus-plus"
  "sideprotocol_plonky2-gpu|https://github.com/sideprotocol/plonky2-gpu"
  "SVRTK_svrtk-docker-gpu|https://github.com/SVRTK/svrtk-docker-gpu"
  "PluralisResearch_node0|https://github.com/PluralisResearch/node0"
  "perslev_U-Time|https://github.com/perslev/U-Time"
  "EsmaeilNarimissa_SciDOCX|https://github.com/EsmaeilNarimissa/SciDOCX"
  "nesaorg_bootstrap|https://github.com/nesaorg/bootstrap"
  "NVIDIA-AI-Blueprints_pdf-to-podcast|https://github.com/NVIDIA-AI-Blueprints/pdf-to-podcast"
  "lllyasviel_Fooocus|https://github.com/lllyasviel/Fooocus"
  "nyu-systems_CLM-GS|https://github.com/nyu-systems/CLM-GS"
  "MouseLand_Kilosort|https://github.com/MouseLand/Kilosort"
  "NVIDIA-NeMo_Gym|https://github.com/NVIDIA-NeMo/Gym"
  "NVIDIA_tao_tutorials|https://github.com/NVIDIA/tao_tutorials"
)

failed=()
ok=0
skipped=0

for entry in "${repos[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  target="${DATA_DIR}/${name}"

  if [ -d "${target}/.git" ] || { [ -d "${target}" ] && [ -n "$(ls -A "${target}" 2>/dev/null || true)" ]; }; then
    echo "[SKIP] ${name} already exists at ${target}"
    skipped=$((skipped + 1))
    continue
  fi

  echo "[CLONE] ${name} <- ${url}"
  if git clone --depth 1 "${url}" "${target}"; then
    ok=$((ok + 1))
  else
    echo "  -> FAILED"
    failed+=("${name}")
    # Clean up partial clone so re-runs work
    rm -rf "${target}"
  fi
done

echo
echo "============================================================"
echo "Cloned:  ${ok}"
echo "Skipped: ${skipped}"
echo "Failed:  ${#failed[@]}"
if [ ${#failed[@]} -gt 0 ]; then
  echo "Failures:"
  for f in "${failed[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi
