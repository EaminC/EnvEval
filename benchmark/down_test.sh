#!/bin/bash

# Clone Dockerfiles to be evaluated
git clone https://github.com/EaminC/ENVGYM-baseline.git

# Dataset list generated from Excel file
repos=(
"Fairify|https://github.com/sumonbis/Fairify.git"
"facebook_zstd|https://github.com/facebook/zstd"
"Baleen|https://github.com/wonglkd/Baleen-FAST24"
"BurntSushi_ripgrep|https://github.com/BurntSushi/ripgrep"
"CrossPrefetch|https://github.com/RutgersCSSystems/crossprefetch-asplos24-artifacts"
"ELECT|https://github.com/tinoryj/ELECT"
"Lottory|https://github.com/rahulvigneswaran/Lottery-Ticket-Hypothesis-in-Pytorch"
"RSNN|https://github.com/fmi-basel/neural-decoding-RSNN"
"P4Ctl|https://github.com/peng-gao-lab/p4control"
"Metis|https://github.com/sbu-fsl/Metis"
"Kong_insomnia|https://github.com/Kong/insomnia"
)

# Create data directory if it doesn't exist
mkdir -p ./data

# Clone function
for entry in "${repos[@]}"; do
  name=$(echo "$entry" | cut -d '|' -f 1)
  url=$(echo "$entry" | cut -d '|' -f 2)

  if [ -d "./data/$name" ]; then
    echo "[SKIP] $name already exists"
  else
    echo "[CLONE] $name ..."
    git clone --recurse-submodules "$url" "./data/$name"
  fi
done

echo "All datasets downloaded successfully!"
