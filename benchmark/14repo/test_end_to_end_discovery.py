"""
End-to-end discovery test (no Docker, no real evaluation).

Walks the same code paths run_14_repos.py would, but stops just before
launching DockerfileEvaluator. Confirms that for every (repo, dockerfile)
pair we'd evaluate:
   - dockerfile exists on disk
   - find_dockerfiles produces the same list as direct rglob would
   - extract_model_info gives the expected ours-<provider>/<model> label
   - create_report_path produces a valid, non-colliding output path
   - the rubric file is loadable & validates

Run from: benchmark/14repo/
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCHMARK = HERE.parent
sys.path.insert(0, str(BENCHMARK))

from batch_evaluate import (  # type: ignore
    find_dockerfiles, create_report_path, extract_model_info,
    validate_rubric,
)
from run_14_repos import REPOS_14  # type: ignore


def main() -> int:
    baseline_dir = HERE / "ENVGYM-14repo"
    rubric_dir   = BENCHMARK / "rubrics" / "manual"
    reports_by_model = HERE / "reports-by-model"

    if not baseline_dir.is_dir():
        print(f"ERROR: {baseline_dir} missing. Run reorganize_14_dockerfiles.py first.")
        return 1
    if not rubric_dir.is_dir():
        print(f"ERROR: {rubric_dir} missing.")
        return 1

    failures = []
    seen_report_paths = {}
    expected_models = {
        "ours-anthropic/claude-opus-4",
        "ours-tensorblock/gpt-4.1",
        "ours-tensorblock/gpt-4.1-mini",
    }
    seen_models = set()
    n_pairs = 0

    for repo in REPOS_14:
        # Rubric must validate
        rubric_path = rubric_dir / f"{repo}.json"
        ok, errs = validate_rubric(rubric_path, repo)
        if not ok:
            failures.append(f"{repo}: rubric invalid ({len(errs)} errs)")
            continue

        # Rubric must be loadable JSON with a 'tests' list
        try:
            with rubric_path.open("r", encoding="utf-8") as f:
                rubric = json.load(f)
        except Exception as e:
            failures.append(f"{repo}: rubric unloadable: {e}")
            continue
        if rubric.get("repo") != repo:
            failures.append(f"{repo}: rubric.repo='{rubric.get('repo')}' != filename")

        # find_dockerfiles must succeed
        dockerfiles = find_dockerfiles(repo, str(baseline_dir))
        if len(dockerfiles) != 3:
            failures.append(f"{repo}: expected 3 dockerfiles, got {len(dockerfiles)}")

        # Cross-check against direct rglob filtered by repo dir name segment.
        # The "ground truth" is the set of envgym.dockerfile files where the
        # repo's canonical name is a path segment.
        direct = [str(p) for p in baseline_dir.rglob("envgym.dockerfile")
                  if repo in p.parts]
        if len(direct) != 3:
            failures.append(f"{repo}: rglob ground-truth got {len(direct)}, expected 3")
        # Cross-check find_dockerfiles output against ground truth (set equality).
        if set(dockerfiles_paths := [d for d, _ in dockerfiles]) != set(direct):
            extra = set(dockerfiles_paths) - set(direct)
            missing = set(direct) - set(dockerfiles_paths)
            failures.append(
                f"{repo}: find_dockerfiles disagrees with rglob; "
                f"+{extra}, -{missing}"
            )

        # Per-pair checks
        for dockerfile_path, relative_path in dockerfiles:
            n_pairs += 1
            df = Path(dockerfile_path)
            if not df.is_file():
                failures.append(f"{repo}: dockerfile not on disk: {dockerfile_path}")

            model = extract_model_info(relative_path)
            seen_models.add(model)
            if model not in expected_models:
                failures.append(f"{repo}: unexpected model label '{model}'")

            rp = create_report_path(relative_path, str(reports_by_model))
            if rp in seen_report_paths:
                failures.append(
                    f"{repo}: report path collision with "
                    f"{seen_report_paths[rp]}: {rp}"
                )
            else:
                seen_report_paths[rp] = repo

            # Validate rp ends in evaluation_report.json and contains both repo and model
            if not rp.endswith("evaluation_report.json"):
                failures.append(f"{repo}: report path doesn't end in "
                                f"evaluation_report.json: {rp}")
            if repo not in rp:
                failures.append(f"{repo}: report path missing repo: {rp}")

    print(f"Pairs checked:       {n_pairs}  (expected 42)")
    print(f"Distinct models:     {sorted(seen_models)}")
    print(f"Distinct report paths: {len(seen_report_paths)}")
    if failures:
        print(f"\nFailures ({len(failures)}):")
        for f in failures[:30]:
            print(f"  - {f}")
        if len(failures) > 30:
            print(f"  ... and {len(failures) - 30} more")
        return 2

    if n_pairs != 42:
        print("ERROR: expected 42 pairs (3 methods x 14 repos).")
        return 3
    if seen_models != expected_models:
        print(f"ERROR: model label mismatch. Saw {seen_models} vs expected {expected_models}.")
        return 4
    if len(seen_report_paths) != 42:
        print("ERROR: report path collisions detected; not all 42 paths unique.")
        return 5

    print("\nAll discovery checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
