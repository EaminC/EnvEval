"""
Smoke test: confirm that the existing batch_evaluate.find_dockerfiles +
batch_evaluate.create_report_path + batch_evaluate.extract_model_info logic
correctly discovers and labels every dockerfile in the reorganized tree.

Resolves paths relative to this file so it works from any cwd.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCHMARK = HERE.parent
DEFAULT_BASELINE_DIR = HERE / "ENVGYM-14repo"

# Import existing benchmark helpers
sys.path.insert(0, str(BENCHMARK))
from batch_evaluate import (  # type: ignore
    find_dockerfiles, create_report_path, extract_model_info,
)

REPO_NAMES_14 = [
    "TIO-IKIM_CellViT-Inference",
    "sideprotocol_plonky2-gpu",
    "SVRTK_svrtk-docker-gpu",
    "PluralisResearch_node0",
    "perslev_U-Time",
    "EsmaeilNarimissa_SciDOCX",
    "nesaorg_bootstrap",
    "NVIDIA-AI-Blueprints_pdf-to-podcast",
    "lllyasviel_Fooocus",
    "TIO-IKIM_CellViT-plus-plus",
    "nyu-systems_CLM-GS",
    "MouseLand_Kilosort",
    "NVIDIA-NeMo_Gym",
    "NVIDIA_tao_tutorials",
]
EXPECTED_PER_REPO = 3  # 3 methods


def main() -> int:
    baseline_dir = DEFAULT_BASELINE_DIR
    if not baseline_dir.is_dir():
        print(f"ERROR: {baseline_dir} not found. Run reorganize_14_dockerfiles.py first.",
              file=sys.stderr)
        return 1

    failures = 0
    total_dockerfiles = 0
    seen_models = set()

    for repo in REPO_NAMES_14:
        dockerfiles = find_dockerfiles(repo, str(baseline_dir))
        n = len(dockerfiles)
        total_dockerfiles += n
        if n != EXPECTED_PER_REPO:
            print(f"  [FAIL] {repo}: expected {EXPECTED_PER_REPO} dockerfiles, got {n}")
            failures += 1
            continue

        # Quick sanity check on each match: paths and labels.
        bad = []
        for dockerfile_path, relative_path in dockerfiles:
            if repo not in dockerfile_path:
                bad.append(f"path missing repo name: {dockerfile_path}")
            if not Path(dockerfile_path).is_file():
                bad.append(f"file not found: {dockerfile_path}")
            model = extract_model_info(relative_path)
            seen_models.add(model)
            # Construct what the report path would be (does not need to exist).
            _rp = create_report_path(relative_path, "reports-by-model")

        if bad:
            print(f"  [FAIL] {repo}:")
            for b in bad[:3]:
                print(f"          - {b}")
            failures += 1
        else:
            sample = ", ".join(extract_model_info(rp) for _, rp in dockerfiles)
            print(f"  [OK  ] {repo:<40} {n} dockerfiles  models=[{sample}]")

    print()
    print(f"Total dockerfiles: {total_dockerfiles}  (expected {len(REPO_NAMES_14) * EXPECTED_PER_REPO})")
    print(f"Distinct models: {sorted(seen_models)}")
    print(f"Failures: {failures}/{len(REPO_NAMES_14)}")

    # Sanity: there should be exactly 3 distinct models.
    if len(seen_models) != 3:
        print(f"  [WARN] expected 3 distinct model labels, saw {len(seen_models)}")

    # Cross-check: total file count by rglob
    all_dfs = list(baseline_dir.rglob("envgym.dockerfile"))
    if total_dockerfiles != len(all_dfs):
        print(f"  [WARN] sum of per-repo finds ({total_dockerfiles}) != "
              f"rglob total ({len(all_dfs)}). "
              "Could be substring collision, investigate.")

    return 0 if failures == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
