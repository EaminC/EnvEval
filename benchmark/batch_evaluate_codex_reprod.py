import subprocess
import json
import os
import sys
import csv
from pathlib import Path
from typing import List, Tuple, Dict, Any, Optional

from DockerfileEvaluator import DockerfileEvaluator

def get_report_filename(repo_name: str) -> Path:
    report_file = "codex-gpt41mini_report.json"
    return Path(__file__).parent / "reports-by-repo" / repo_name / report_file

def main():
    # Built-in defaults (no CLI args)
    baseline_output = Path(__file__).parent / "Baseline-codex-with-traj" / "output"
    rubric_dir = Path(__file__).parent / "rubrics" / "manual"
    report_dir = Path(__file__).parent / "reports-by-repo"
    
    skip_warnings = False
    verbose = False

    # 1. Verify baseline output dir exists
    if not baseline_output.exists() or not baseline_output.is_dir():
        raise Exception(f"Error: baseline output directory not found: {baseline_output}")

    # 2. Verify rubric dir exists
    if not rubric_dir.exists() or not rubric_dir.is_dir():
        raise Exception(f"Error: rubric directory not found: {rubric_dir}")

    # 3. Validate dockerfiles and rubrics for each repo
    missing_dockerfiles = []
    missing_rubrics = []
    repos = [p for p in baseline_output.iterdir() if p.is_dir()]

    for repo_path in repos:
        repo_name = repo_path.name
        dockerfile_path = repo_path / "codex.dockerfile"
        rubric_path = rubric_dir / f"{repo_name}.json"

        if not dockerfile_path.exists():
            missing_dockerfiles.append(str(dockerfile_path))
        if not rubric_path.exists():
            missing_rubrics.append(str(rubric_path))

    if missing_dockerfiles or missing_rubrics:
        if missing_dockerfiles:
            print("Missing dockerfiles:")
            for p in missing_dockerfiles:
                print(f" - {p}")
        if missing_rubrics:
            print("Missing rubrics:")
            for p in missing_rubrics:
                print(f" - {p}")
        print("WARNING: One or more required files are missing. Aborting.")
        #raise Exception("One or more required files are missing. Aborting.")

    # Ensure report dir existss
    report_dir.mkdir(parents=True, exist_ok=True)

    any_failures = False
    results_summary = []

    # 4. Evaluate each dockerfile
    for repo_path in repos:
        repo_name = repo_path.name
        dockerfile_path = repo_path / "codex.dockerfile"
        print(f"\nEvaluating repo: {repo_name}")

        evaluator = DockerfileEvaluator(repo_name, str(dockerfile_path), str(rubric_dir), skip_warnings)
        report = None
        error_messages = []

        try:
            report = evaluator.evaluate()
        except KeyboardInterrupt:
            print("Evaluation interrupted by user")
            error_messages.append("Evaluation interrupted by user (KeyboardInterrupt)")
            try:
                report = evaluator.generate_report()
            except Exception as gen_ex:
                error_messages.append(f"Failed to generate report after interrupt: {gen_ex}")
                report = {"repo": repo_name, "errors": error_messages}
            
            # Save partial report before exiting
            out_file = get_report_filename(repo_name)
            try:
                if report:
                    if isinstance(report, dict) and 'errors' not in report:
                        report['errors'] = error_messages
                    with open(out_file, 'w', encoding='utf-8') as f:
                        json.dump(report, f, indent=2)
                    print(f"Saved partial report -> {out_file}")
            except Exception as save_ex:
                print(f"Failed to save partial report: {save_ex}")
            
            try:
                evaluator.cleanup()
            except Exception:
                pass
            sys.exit(130)
        except Exception as e:
            error_msg = f"Evaluation raised exception: {type(e).__name__}: {e}"
            print(f"Evaluation for {repo_name} raised an exception: {e}")
            error_messages.append(error_msg)
            try:
                report = evaluator.generate_report()
            except Exception as gen_ex:
                error_messages.append(f"Failed to generate report after error: {gen_ex}")
                report = {"repo": repo_name, "errors": error_messages}
            any_failures = True

        # Append any error messages to the report
        if error_messages and report:
            if isinstance(report, dict):
                if 'errors' not in report:
                    report['errors'] = []
                report['errors'].extend(error_messages)

        # Save report (always, even partial)
        #out_file = report_dir / f"{repo_name}.json"
        out_file = report_dir / repo_name / "models" / "codex-gpt41mini_report.json"
        try:
            if report:
                with open(out_file, 'w', encoding='utf-8') as f:
                    json.dump(report, f, indent=2)
                print(f"Saved report -> {out_file}")
            else:
                # Create minimal error report if no report exists
                error_report = {"repo": repo_name, "errors": error_messages or ["Unknown error: no report generated"]}
                with open(out_file, 'w', encoding='utf-8') as f:
                    json.dump(error_report, f, indent=2)
                print(f"Saved error report -> {out_file}")
                any_failures = True
        except Exception as e:
            print(f"Failed to save report for {repo_name}: {e}")
            any_failures = True

        # Determine if this repo had failing tests
        try:
            summary = report.get('summary', {}) if isinstance(report, dict) else {}
            failed_tests = summary.get('failed_tests', 0)
            if failed_tests and failed_tests > 0:
                any_failures = True
        except Exception:
            any_failures = True

    # 5. Exit code
    if any_failures:
        print("\nOne or more evaluations failed or were incomplete.")
        sys.exit(1)
    else:
        print("\nAll evaluations completed successfully.")
        sys.exit(0)


if __name__ == '__main__':
    main()