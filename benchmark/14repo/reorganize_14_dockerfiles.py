"""
Reorganize EnvGym-14Add into an ENVGYM-baseline-style layout suitable for
batch_evaluate.find_dockerfiles to discover.

Source layout (as cloned from https://github.com/EaminC/EnvGym-14Add):
  <repo_root>/backup_<ts>_<provider>_<model>_envgym/<repo>/envgym/envgym.dockerfile

Target layout (the script writes here):
  <out_dir>/ours-<provider>/<model>/<canonical_repo>/envgym/envgym.dockerfile

The canonical repo name is the <org>_<repo> rubric form (e.g. lllyasviel_Fooocus).

Why this layout: it matches the existing ENVGYM-baseline convention (e.g.
ENVGYM-baseline/ours/claude/35haiku/<repo>/envgym.dockerfile) so that the
existing batch_evaluate / DockerfileEvaluator pipeline finds them via the
recursive search and produces sensible model labels.

This script does NOT modify the EnvGym-14Add clone; it copies files out.

Usage:
  python reorganize_14_dockerfiles.py \\
        --src    ../../EnvGym-14Add \\
        --out    ENVGYM-14repo

Run from: benchmark/14repo/   (or pass absolute paths)
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

# bare-name (in EnvGym-14Add) -> canonical org_repo name (matches rubric)
REPO_RENAME = {
    "ai-avatar":          "lllyasviel_Fooocus",
    "CellViT-Inference":  "TIO-IKIM_CellViT-Inference",
    "CellViT-plus-plus":  "TIO-IKIM_CellViT-plus-plus",
    "CLM-GS":             "nyu-systems_CLM-GS",
    "Kilosort4":          "MouseLand_Kilosort",
    "NeMo_Gym":           "NVIDIA-NeMo_Gym",
    "nesa_bootstrap":     "nesaorg_bootstrap",
    "node0":              "PluralisResearch_node0",
    "pdf-to-podcast":     "NVIDIA-AI-Blueprints_pdf-to-podcast",
    "plonky2-gpu":        "sideprotocol_plonky2-gpu",
    "SciDOCX":            "EsmaeilNarimissa_SciDOCX",
    "SVRTK_Docker_GPU":   "SVRTK_svrtk-docker-gpu",
    "tao_tutorials":      "NVIDIA_tao_tutorials",
    "U-Time":             "perslev_U-Time",
}

# Backup dir name -> (provider, model) for the target layout
BACKUP_TO_PROVIDER_MODEL = {
    "backup_20260501_152924_tensorblock_gpt-4.1-mini_envgym":     ("tensorblock", "gpt-4.1-mini"),
    "backup_20260501_214624_tensorblock_gpt-4.1_envgym":          ("tensorblock", "gpt-4.1"),
    "backup_20260507_030750_anthropic_claude-opus-4-20250514_envgym": ("anthropic", "claude-opus-4"),
}


def copy_dockerfile(src_dir: Path, dst_dir: Path) -> bool:
    """Copy <src_dir>/envgym.dockerfile to <dst_dir>/envgym.dockerfile.
    Returns True on success."""
    src = src_dir / "envgym.dockerfile"
    if not src.is_file():
        return False
    dst_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst_dir / "envgym.dockerfile")
    return True


def reorganize(src_root: Path, out_root: Path, copy_metadata: bool = False,
               dry_run: bool = False) -> int:
    """Reorganize EnvGym-14Add into the target layout.

    Args:
        src_root: path to the EnvGym-14Add repo root (contains the 3 backup_* dirs).
        out_root: path to write the new tree to.
        copy_metadata: if True, also copy auxiliary files (history.txt, plan.txt, etc.)
            next to the dockerfile. Off by default to keep the build context tiny.
        dry_run: if True, only report what would be done.

    Returns: number of dockerfiles copied (or that would be copied in dry-run).
    """
    if not src_root.is_dir():
        print(f"ERROR: source dir does not exist: {src_root}", file=sys.stderr)
        return -1

    n_copied = 0
    n_missing_dockerfile = 0
    n_unknown_repo = 0

    for backup_name, (provider, model) in BACKUP_TO_PROVIDER_MODEL.items():
        backup_dir = src_root / backup_name
        if not backup_dir.is_dir():
            print(f"  [WARN] backup dir not found: {backup_dir.name}")
            continue

        for repo_dir in sorted(p for p in backup_dir.iterdir() if p.is_dir()):
            bare = repo_dir.name
            # Skip the duplicate/artifact "Untitled/" inside the claude-opus-4 backup.
            if bare == "Untitled":
                print(f"  [SKIP] {backup_name}/{bare}: artifact directory")
                continue
            if bare not in REPO_RENAME:
                print(f"  [WARN] {backup_name}/{bare}: not in rename map; skipping")
                n_unknown_repo += 1
                continue

            canonical = REPO_RENAME[bare]
            envgym_subdir = repo_dir / "envgym"
            if not envgym_subdir.is_dir():
                print(f"  [WARN] {backup_name}/{bare}: no envgym/ subdir")
                n_missing_dockerfile += 1
                continue
            df = envgym_subdir / "envgym.dockerfile"
            if not df.is_file():
                print(f"  [WARN] {backup_name}/{bare}: no envgym.dockerfile")
                n_missing_dockerfile += 1
                continue

            dst_dir = out_root / f"ours-{provider}" / model / canonical / "envgym"
            print(f"  [{'DRYRUN' if dry_run else 'COPY  '}] "
                  f"{provider}/{model:<14} {bare:<20} -> {canonical}")
            if not dry_run:
                dst_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(df, dst_dir / "envgym.dockerfile")
                if copy_metadata:
                    # Copy useful aux files alongside (non-recursive).
                    for fname in ("hardware.txt", "plan.txt", "stat.json",
                                  "documents.json", "log.txt"):
                        src_aux = envgym_subdir / fname
                        if src_aux.is_file():
                            shutil.copy2(src_aux, dst_dir / fname)
            n_copied += 1

    print()
    print(f"Reorganized {n_copied} dockerfiles into {out_root}")
    if n_missing_dockerfile:
        print(f"  {n_missing_dockerfile} repos had no envgym.dockerfile")
    if n_unknown_repo:
        print(f"  {n_unknown_repo} repo dirs had no canonical name mapping")

    expected = len(BACKUP_TO_PROVIDER_MODEL) * len(REPO_RENAME)  # 3 * 14 = 42
    if n_copied != expected and not dry_run:
        print(f"  WARNING: expected {expected} dockerfiles (3 methods x 14 repos), "
              f"got {n_copied}")
    return n_copied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default="../../../EnvGym-14Add",
                        help="Path to the EnvGym-14Add clone root "
                             "(default: ../../../EnvGym-14Add relative to this script).")
    parser.add_argument("--out", default="ENVGYM-14repo",
                        help="Output directory for the reorganized tree "
                             "(default: ./ENVGYM-14repo).")
    parser.add_argument("--copy-metadata", action="store_true",
                        help="Also copy hardware.txt, plan.txt etc. next to each dockerfile.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be done without copying.")
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    src = (here / args.src).resolve() if not Path(args.src).is_absolute() \
                                      else Path(args.src).resolve()
    out = (here / args.out).resolve() if not Path(args.out).is_absolute() \
                                      else Path(args.out).resolve()

    print(f"Source:  {src}")
    print(f"Output:  {out}")
    print()
    n = reorganize(src, out, copy_metadata=args.copy_metadata, dry_run=args.dry_run)
    return 0 if n >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())
