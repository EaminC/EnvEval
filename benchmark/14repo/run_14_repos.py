#!/usr/bin/env python3
"""
Standalone runner for the 14-repo EnvEval extension.

This is the 14-repo equivalent of benchmark/run_all_repos.py, with three
key differences:

  1. Hard-coded list of 14 canonical repo names; does NOT scan rubrics/manual/
     for files (which would also pick up the existing 51-repo set).
  2. Uses the reorganized dockerfile tree at benchmark/14repo/ENVGYM-14repo/.
  3. Writes all reports under benchmark/14repo/reports-by-{model,repo}/ so the
     14-repo run is fully isolated from the original 54-repo results.

Like the original runner, this orchestrates batch_evaluate.py per repo, in
batches of N repos at a time, optionally via screen sessions for ssh-safety.

Usage examples:
    # Linux, screen-orchestrated (recommended for long runs)
    python3 run_14_repos.py --batch-size 4

    # Linux, no screen (sequential, in-process)
    python3 run_14_repos.py --batch-size 1 --no-screen

    # Smoke test on just a couple repos
    python3 run_14_repos.py --repos lllyasviel_Fooocus,MouseLand_Kilosort --no-screen

    # Dry run: validate everything but don't actually launch DockerfileEvaluator
    python3 run_14_repos.py --dry-run

Run from: benchmark/14repo/
"""

from __future__ import annotations

import argparse
import os
import random
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Locate the existing benchmark scripts (one dir up).
HERE = Path(__file__).resolve().parent
BENCHMARK = HERE.parent
sys.path.insert(0, str(BENCHMARK))

from batch_evaluate import (  # type: ignore
    find_dockerfiles, validate_all_rubrics,
)

# Canonical repo names in display order: paired families first (none here, all
# EnvGym-only), then alphabetical for the rest. Order does not affect
# correctness; it just affects log readability.
REPOS_14 = [
    "EsmaeilNarimissa_SciDOCX",
    "lllyasviel_Fooocus",
    "MouseLand_Kilosort",
    "nesaorg_bootstrap",
    "NVIDIA-AI-Blueprints_pdf-to-podcast",
    "NVIDIA-NeMo_Gym",
    "NVIDIA_tao_tutorials",
    "nyu-systems_CLM-GS",
    "perslev_U-Time",
    "PluralisResearch_node0",
    "sideprotocol_plonky2-gpu",
    "SVRTK_svrtk-docker-gpu",
    "TIO-IKIM_CellViT-Inference",
    "TIO-IKIM_CellViT-plus-plus",
]

# Defaults relative to this script. Override via CLI flags.
DEFAULT_BASELINE_DIR = HERE / "ENVGYM-14repo"
DEFAULT_RUBRIC_DIR   = BENCHMARK / "rubrics" / "manual"
DEFAULT_REPORTS_BY_MODEL = HERE / "reports-by-model"
DEFAULT_REPORTS_BY_REPO  = HERE / "reports-by-repo"
DEFAULT_DATA_DIR     = BENCHMARK / "data"


# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

def preflight(repos, baseline_dir: Path, rubric_dir: Path,
              data_dir: Path, expect_data: bool) -> int:
    """Validate that every prerequisite exists. Returns count of issues."""
    issues = 0

    print("Pre-flight checks:")
    print(f"  baseline-dir = {baseline_dir}")
    print(f"  rubric-dir   = {rubric_dir}")
    print(f"  data-dir     = {data_dir}")
    print()

    if not baseline_dir.is_dir():
        print(f"  [FAIL] baseline dir not found: {baseline_dir}")
        print("         Run reorganize_14_dockerfiles.py first.")
        issues += 1

    if not rubric_dir.is_dir():
        print(f"  [FAIL] rubric dir not found: {rubric_dir}")
        issues += 1

    # Per-repo checks
    for repo in repos:
        # Rubric file
        rubric = rubric_dir / f"{repo}.json"
        if not rubric.is_file():
            print(f"  [FAIL] {repo}: rubric not found at {rubric}")
            issues += 1

        # Dockerfiles for this repo
        if baseline_dir.is_dir():
            dockerfiles = find_dockerfiles(repo, str(baseline_dir))
            if not dockerfiles:
                print(f"  [FAIL] {repo}: no dockerfiles under {baseline_dir}")
                issues += 1

        # Source repo present in data/?
        if expect_data:
            data_path = data_dir / repo
            if not data_path.is_dir():
                print(f"  [WARN] {repo}: source not at {data_path}. "
                      "Run down_14.sh or pass --skip-data-check.")
                # Not fatal: dockerfile may not need source. Don't increment issues.

    # Rubric structural validation via existing helper
    if rubric_dir.is_dir():
        validation = validate_all_rubrics(repos, str(rubric_dir))
        bad = {r: errs for r, errs in validation.items() if errs}
        if bad:
            print(f"  [FAIL] rubric validation: {len(bad)} repo(s) have errors")
            for r, errs in bad.items():
                print(f"           {r}: {len(errs)} error(s); first: {errs[0]}")
            issues += len(bad)
        else:
            print(f"  [OK]  all {len(repos)} rubrics validated")

    return issues


# ---------------------------------------------------------------------------
# Screen orchestration (mirrors run_all_repos.py with light cleanup)
# ---------------------------------------------------------------------------

def has_screen() -> bool:
    return shutil.which("screen") is not None


def count_running_screens(repo_names, session_code):
    try:
        result = subprocess.run(["screen", "-ls"], capture_output=True, text=True)
        screen_output = result.stdout
        running, finished = [], []
        for repo in repo_names:
            screen_name = f"{session_code}_{repo}"
            if f".{screen_name}\t" in screen_output or f".{screen_name} " in screen_output:
                running.append(repo)
            else:
                finished.append(repo)
        return True, len(running), running, finished
    except FileNotFoundError:
        return False, 0, [], list(repo_names)


def wait_for_batch(batch_repos, session_code, check_interval):
    print(f"Waiting for batch of {len(batch_repos)} repos...")
    start = time.time()
    while True:
        ok, n_running, running, _ = count_running_screens(batch_repos, session_code)
        if not ok:
            print(f"Cannot check screens, retrying in {check_interval}s...")
            time.sleep(check_interval)
            continue
        if n_running == 0:
            print(f"Batch finished in {time.time() - start:.1f}s.")
            return
        elapsed = time.time() - start
        print(f"[{elapsed:.0f}s] Still running {n_running}/{len(batch_repos)}: "
              f"{', '.join(running)}")
        time.sleep(check_interval)


def launch_repo_screen(repo, session_code, baseline_dir, rubric_dir,
                       reports_by_model_dir, reports_by_repo_dir):
    """Launch batch_evaluate.py for a single repo inside a detached screen."""
    screen_name = f"{session_code}_{repo}"
    cmd = [
        "screen", "-dmS", screen_name, "bash", "-c",
        f"cd '{BENCHMARK}' && python3 batch_evaluate.py "
        f"--skip-warnings --verbose "
        f"--rubric-dir '{rubric_dir}' "
        f"--baseline-dir '{baseline_dir}' "
        f"--reports-by-model-dir '{reports_by_model_dir}' "
        f"--reports-by-repo-dir '{reports_by_repo_dir}' "
        f"--repo '{repo}'",
    ]
    print(f"  Starting screen '{screen_name}'")
    subprocess.run(cmd, check=True)
    return screen_name


def launch_repo_inline(repo, baseline_dir, rubric_dir,
                       reports_by_model_dir, reports_by_repo_dir):
    """Run batch_evaluate.py for a single repo inline (no screen)."""
    cmd = [
        sys.executable, "batch_evaluate.py",
        "--skip-warnings", "--verbose",
        "--rubric-dir", str(rubric_dir),
        "--baseline-dir", str(baseline_dir),
        "--reports-by-model-dir", str(reports_by_model_dir),
        "--reports-by-repo-dir", str(reports_by_repo_dir),
        "--repo", repo,
    ]
    print(f"  Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=False, cwd=str(BENCHMARK))


def docker_cleanup() -> None:
    if shutil.which("docker") is None:
        print("docker not found, skipping cleanup.")
        return
    try:
        subprocess.run(
            ["docker", "system", "prune", "-a", "--volumes", "-f"],
            capture_output=True, text=True, check=True,
        )
        print("Docker cleanup OK.")
    except subprocess.CalledProcessError as e:
        print(f"Docker cleanup failed: {e}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--batch-size", type=int, default=4,
                   help="Number of repos to evaluate concurrently (default: 4).")
    p.add_argument("--check-interval", type=int, default=30,
                   help="How often to poll screen liveness, seconds (default: 30).")
    p.add_argument("--baseline-dir", default=str(DEFAULT_BASELINE_DIR),
                   help="Path to ENVGYM-14repo dockerfile tree.")
    p.add_argument("--rubric-dir", default=str(DEFAULT_RUBRIC_DIR),
                   help="Path to rubrics dir (default: benchmark/rubrics/manual/).")
    p.add_argument("--reports-by-model-dir", default=str(DEFAULT_REPORTS_BY_MODEL),
                   help="Path to write per-model reports.")
    p.add_argument("--reports-by-repo-dir", default=str(DEFAULT_REPORTS_BY_REPO),
                   help="Path to write per-repo reports.")
    p.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR),
                   help="Path to source-repo data dir (default: benchmark/data/).")
    p.add_argument("--repos",
                   help="Comma-separated subset of canonical repo names; default = all 14.")
    p.add_argument("--no-screen", action="store_true",
                   help="Run inline instead of via screen sessions.")
    p.add_argument("--skip-docker-cleanup", action="store_true",
                   help="Don't run 'docker system prune' between batches.")
    p.add_argument("--skip-data-check", action="store_true",
                   help="Don't warn about missing data/<repo>/ source dirs.")
    p.add_argument("--dry-run", action="store_true",
                   help="Run preflight only; don't launch any builds.")
    args = p.parse_args()

    # Resolve paths
    baseline_dir = Path(args.baseline_dir).resolve()
    rubric_dir   = Path(args.rubric_dir).resolve()
    reports_by_model_dir = Path(args.reports_by_model_dir).resolve()
    reports_by_repo_dir  = Path(args.reports_by_repo_dir).resolve()
    data_dir     = Path(args.data_dir).resolve()

    # Pick repo list
    if args.repos:
        repos = [r.strip() for r in args.repos.split(",") if r.strip()]
        unknown = [r for r in repos if r not in REPOS_14]
        if unknown:
            print(f"ERROR: unknown repo(s) (not in 14-repo set): {unknown}")
            print(f"Known repos: {REPOS_14}")
            return 2
    else:
        repos = list(REPOS_14)

    # Session code identifies this run uniquely (prefix on every screen name).
    session_code = f"eval14_{int(time.time())}_{random.randint(1000, 9999)}"

    print(f"=== EnvEval 14-repo runner ===")
    print(f"Session code:   {session_code}")
    print(f"Repos to run:   {len(repos)}")
    print(f"Batch size:     {args.batch_size}")
    print(f"Use screen:     {not args.no_screen and has_screen()}")
    print()

    issues = preflight(repos, baseline_dir, rubric_dir, data_dir,
                       expect_data=not args.skip_data_check)
    if issues:
        print(f"\nPre-flight failed with {issues} issue(s). Aborting.")
        return 3
    print()

    if args.dry_run:
        print("Dry run requested; exiting before launching evaluations.")
        return 0

    # Ensure output dirs exist
    reports_by_model_dir.mkdir(parents=True, exist_ok=True)
    reports_by_repo_dir.mkdir(parents=True, exist_ok=True)

    use_screen = (not args.no_screen) and has_screen()
    if not use_screen and not args.no_screen:
        print("WARN: 'screen' not on PATH; falling back to inline execution.")

    n_batches = (len(repos) + args.batch_size - 1) // args.batch_size
    completed = []

    for b in range(n_batches):
        batch = repos[b * args.batch_size : (b + 1) * args.batch_size]
        print(f"\n--- Batch {b + 1}/{n_batches}: {batch} ---")

        if use_screen:
            launched = []
            for repo in batch:
                try:
                    launch_repo_screen(repo, session_code, baseline_dir,
                                       rubric_dir, reports_by_model_dir,
                                       reports_by_repo_dir)
                    launched.append(repo)
                except Exception as e:
                    print(f"  Failed to launch {repo}: {e}")
            if launched:
                time.sleep(5)
                wait_for_batch(launched, session_code, args.check_interval)
                completed.extend(launched)
        else:
            for repo in batch:
                launch_repo_inline(repo, baseline_dir, rubric_dir,
                                   reports_by_model_dir, reports_by_repo_dir)
                completed.append(repo)

        if not args.skip_docker_cleanup:
            time.sleep(5)
            docker_cleanup()

    print()
    print("===============================")
    print(f"Completed: {len(completed)}/{len(repos)}")
    print(f"Reports:")
    print(f"  per-model: {reports_by_model_dir}")
    print(f"  per-repo:  {reports_by_repo_dir}")
    if len(completed) < len(repos):
        missing = sorted(set(repos) - set(completed))
        print(f"Missing: {missing}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
