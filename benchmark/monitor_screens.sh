#!/bin/bash

RUBRIC_DIR="rubrics/manual"
TMP_DIR="/tmp/screen_snapshots"
mkdir -p "$TMP_DIR"

# Get all repo names
repos=($(basename -s .json $(ls "$RUBRIC_DIR"/*.json)))

echo "============================================================"
echo "=== 🧭 Repository Screen Monitor"
echo "=== Time: $(date)"
echo "============================================================"
echo

for repo in "${repos[@]}"; do
    echo "------------------------------------------------------------"
    echo "🔹 Repo: $repo"

    if screen -list | grep -q "[.]$repo"; then
        echo "   Status: 🟢 RUNNING"

        # Create a snapshot of the current screen output
        SNAPSHOT_FILE="$TMP_DIR/${repo}_snapshot.txt"
        screen -S "$repo" -X hardcopy "$SNAPSHOT_FILE" 2>/dev/null

        if [[ -f "$SNAPSHOT_FILE" ]]; then
            echo "------------------------------------------------------------"
            tail -n 20 "$SNAPSHOT_FILE" | sed 's/^/      /'
        else
            echo "   ⚠️  Unable to capture screen output (maybe no permissions or empty buffer)."
        fi
    else
        echo "   Status: ⚪ FINISHED (no active screen)"
    fi

    echo
done

echo "============================================================"
echo "✅ Monitoring complete — $(date)"
echo "============================================================"
