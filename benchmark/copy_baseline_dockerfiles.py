#!/usr/bin/env python3
"""
Script to copy dockerfiles from Baseline-codex-with-traj to ENVGYM-baseline.
Validates that source files exist and target directories exist before copying.
"""

import os
import shutil
from pathlib import Path
import sys

def main():
    # Define base paths
    baseline_dir = Path("Baseline-codex-with-traj/output")
    target_base_dir = Path("ENVGYM-baseline/codex/gpt41mini")
    
    # Get all repo directories from baseline
    if not baseline_dir.exists():
        print(f"ERROR: Baseline directory does not exist: {baseline_dir}")
        sys.exit(1)
    
    if not target_base_dir.exists():
        print(f"ERROR: Target base directory does not exist: {target_base_dir}")
        sys.exit(1)
    
    # Get all repo_names from baseline output
    repo_names = [d.name for d in baseline_dir.iterdir() if d.is_dir()]
    
    print(f"Found {len(repo_names)} repositories in Baseline-codex-with-traj/output")
    print()
    
    # Step 1: Check which repos have dockerfiles
    missing_dockerfile = []
    has_dockerfile = []
    
    for repo_name in repo_names:
        dockerfile_path = baseline_dir / repo_name / "codex.dockerfile"
        if not dockerfile_path.exists():
            missing_dockerfile.append(repo_name)
        else:
            has_dockerfile.append(repo_name)
    
    # Report missing dockerfiles
    if missing_dockerfile:
        print(f"WARNING: {len(missing_dockerfile)} repositories missing codex.dockerfile:")
        for repo in missing_dockerfile:
            print(f"  - {repo}")
        print()
    
    print(f"{len(has_dockerfile)} repositories have codex.dockerfile")
    print()
    
    # Step 2: Verify target directories exist for repos with dockerfiles
    target_missing = []
    
    for repo_name in has_dockerfile:
        target_dir = target_base_dir / repo_name
        if not target_dir.exists():
            target_missing.append(repo_name)
    
    if target_missing:
        print(f"ERROR: {len(target_missing)} repositories have dockerfiles but target directory missing:")
        for repo in target_missing:
            print(f"  - {repo}")
        print()
        print("Aborting: Fix directory structure before proceeding.")
        sys.exit(1)
    
    print("All target directories verified.")
    print()
    
    # Step 3: Copy dockerfiles
    print(f"Copying {len(has_dockerfile)} dockerfiles...")
    copied_count = 0
    failed_count = 0
    
    for repo_name in has_dockerfile:
        source_path = baseline_dir / repo_name / "codex.dockerfile"
        target_path = target_base_dir / repo_name / "envgym.dockerfile"
        
        try:
            shutil.copy2(source_path, target_path)
            copied_count += 1
            print(f"  ✓ {repo_name}")
        except Exception as e:
            failed_count += 1
            print(f"  ✗ {repo_name}: {e}")
    
    print()
    print("=" * 60)
    print("SUMMARY:")
    print(f"  Total repositories: {len(repo_names)}")
    print(f"  Missing dockerfile (ignored): {len(missing_dockerfile)}")
    print(f"  Successfully copied: {copied_count}")
    print(f"  Failed to copy: {failed_count}")
    print("=" * 60)
    
    if failed_count > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
