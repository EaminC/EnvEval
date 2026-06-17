"""
Rename and category-fix the 6 bare-name rubrics so they conform to the EnvEval
rubric schema and the <org>_<repo> naming convention.

Idempotent: running twice is fine; if a renamed rubric already exists, the
script leaves it alone but still warns about leftover bare-name files.

Resolves the rubric path relative to this file, so it can be run from any cwd.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

# Default location: ../rubrics/manual (i.e. benchmark/rubrics/manual when this
# file lives at benchmark/14repo/fix_14_rubrics.py).
HERE = Path(__file__).resolve().parent
DEFAULT_RUBRIC_DIR = HERE.parent / "rubrics" / "manual"

# Mapping: old_basename -> (new_basename, upstream_url_for_records)
RENAMES = {
    "ai-avatar":          ("lllyasviel_Fooocus",          "https://github.com/lllyasviel/Fooocus"),
    "CellViT-plus-plus":  ("TIO-IKIM_CellViT-plus-plus",  "https://github.com/TIO-IKIM/CellViT-plus-plus"),
    "CLM-GS":             ("nyu-systems_CLM-GS",          "https://github.com/nyu-systems/CLM-GS"),
    "Kilosort4":          ("MouseLand_Kilosort",          "https://github.com/MouseLand/Kilosort"),
    "NeMo_Gym":           ("NVIDIA-NeMo_Gym",             "https://github.com/NVIDIA-NeMo/Gym"),
    "tao_tutorials":      ("NVIDIA_tao_tutorials",        "https://github.com/NVIDIA/tao_tutorials"),
}

# Test type -> default category. Conservative; matches how the existing
# well-formed rubrics in rubrics/manual/ assign categories.
DEFAULT_CATEGORY_BY_TYPE = {
    "commands_exist":   "configuration",
    "output_contains":  "configuration",
    "envvar_set":       "configuration",
    "files_exist":      "structure",
    "dirs_exist":       "structure",
    "file_contains":    "structure",
    "run_command":      "functionality",
}


def assign_category(test: dict) -> str:
    """Return the category for a test, picking based on its 'type'."""
    t = test.get("type", "")
    cat = DEFAULT_CATEGORY_BY_TYPE.get(t)
    if cat is not None:
        return cat
    # Unknown test type: fall back to functionality which is the safest bucket
    # for "does the project actually run".
    return "functionality"


def fix_rubric(src: Path, dst: Path, new_repo_name: str) -> tuple[int, int]:
    """Read src rubric, write fixed/renamed rubric to dst.
    Returns (n_tests, n_categories_added)."""
    with src.open("r", encoding="utf-8") as f:
        rubric = json.load(f)

    rubric["repo"] = new_repo_name

    n_added = 0
    for test in rubric.get("tests", []):
        if "category" not in test or not test.get("category"):
            test["category"] = assign_category(test)
            n_added += 1

    dst.parent.mkdir(parents=True, exist_ok=True)
    with dst.open("w", encoding="utf-8") as f:
        json.dump(rubric, f, indent=2)
        f.write("\n")
    return len(rubric.get("tests", [])), n_added


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

    summary = []
    for old_name, (new_name, url) in RENAMES.items():
        src = rubric_dir / f"{old_name}.json"
        dst = rubric_dir / f"{new_name}.json"

        if not src.exists() and dst.exists():
            print(f"  [SKIP] {old_name} -> {new_name}: already renamed.")
            summary.append((old_name, new_name, url, "already_done", 0, 0))
            continue
        if not src.exists():
            print(f"  [WARN] {old_name}.json not found and {new_name}.json missing too.")
            summary.append((old_name, new_name, url, "missing", 0, 0))
            continue
        if dst.exists():
            print(f"  [WARN] both {old_name}.json and {new_name}.json exist; "
                  f"refusing to overwrite. Manually pick one.")
            summary.append((old_name, new_name, url, "conflict", 0, 0))
            continue

        n_tests, n_added = fix_rubric(src, dst, new_name)
        src.unlink()
        print(f"  [OK]   {old_name}.json -> {new_name}.json  "
              f"({n_tests} tests, {n_added} categories added)")
        summary.append((old_name, new_name, url, "renamed", n_tests, n_added))

    print()
    print("Summary:")
    print(f"  {'old':<22}{'new':<32}{'status':<14}{'tests':>7}{'+cat':>6}")
    for old_name, new_name, url, status, n_tests, n_added in summary:
        print(f"  {old_name:<22}{new_name:<32}{status:<14}{n_tests:>7}{n_added:>6}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
