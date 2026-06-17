#!/bin/bash
set -e  # stop on error

# Directory containing the rubric JSON files
RUBRIC_DIR="rubrics/manual"

# Find all .json files and strip the extension to get repo names
repos=($(basename -s .json $(ls "$RUBRIC_DIR"/*.json)))

echo "Found ${#repos[@]} repos:"
printf '  - %s\n' "${repos[@]}"
echo

# Launch a detached screen for each repo
for repo in "${repos[@]}"; do
    echo "Starting screen for $repo..."
    screen -dmS "$repo" bash -c "python3 batch_evaluate.py \
        --skip-warnings --verbose \
        --rubric-dir '$RUBRIC_DIR' \
        --repo '$repo'"
    echo "  → Screen '$repo' started."
done

echo
echo "✅ All screens launched! Use 'screen -ls' to see them."
