"""
Validate all 14 new rubrics with batch_evaluate.validate_rubric and confirm
they all pass. Resolves paths relative to this file so it works from any cwd.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCHMARK = HERE.parent
DEFAULT_RUBRIC_DIR = BENCHMARK / "rubrics" / "manual"

# Import the existing validator from batch_evaluate.py
sys.path.insert(0, str(BENCHMARK))
from batch_evaluate import validate_rubric  # type: ignore

REPO_NAMES_14 = [
    # baseline-pair section is none (no head-to-head baselines for these);
    # all 14 are listed in display order. The 8 that were already well-formed:
    "TIO-IKIM_CellViT-Inference",
    "sideprotocol_plonky2-gpu",
    "SVRTK_svrtk-docker-gpu",
    "PluralisResearch_node0",
    "perslev_U-Time",
    "EsmaeilNarimissa_SciDOCX",
    "nesaorg_bootstrap",
    "NVIDIA-AI-Blueprints_pdf-to-podcast",
    # The 6 we just renamed/fixed:
    "lllyasviel_Fooocus",
    "TIO-IKIM_CellViT-plus-plus",
    "nyu-systems_CLM-GS",
    "MouseLand_Kilosort",
    "NVIDIA-NeMo_Gym",
    "NVIDIA_tao_tutorials",
]


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rubric-dir", default=str(DEFAULT_RUBRIC_DIR),
                        help=f"Path to rubrics/manual/ (default: {DEFAULT_RUBRIC_DIR})")
    args = parser.parse_args()

    rubric_dir = Path(args.rubric_dir).resolve()
    if not rubric_dir.is_dir():
        print(f"ERROR: rubric dir not found: {rubric_dir}", file=sys.stderr)
        return 1
    print(f"Rubric dir: {rubric_dir}")
    print()

    failures = 0
    for repo in REPO_NAMES_14:
        path = rubric_dir / f"{repo}.json"
        ok, errs = validate_rubric(path, repo)
        status = "OK  " if ok else "FAIL"
        n_errs = len(errs)
        print(f"  [{status}] {repo:<40} {'' if ok else f'errors={n_errs}'}")
        if not ok:
            failures += 1
            for e in errs[:5]:
                print(f"          - {e}")
            if n_errs > 5:
                print(f"          ... and {n_errs - 5} more")

    print()
    print(f"Validated {len(REPO_NAMES_14)} rubrics, {len(REPO_NAMES_14) - failures} passed, "
          f"{failures} failed.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
