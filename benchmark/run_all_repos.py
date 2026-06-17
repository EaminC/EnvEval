#!/usr/bin/env python3
"""
Python script to launch batch evaluation for all repositories.
Equivalent to run_all_repos.sh but written in Python.
"""

import os
import glob
import subprocess
import sys
import time
import random
import argparse
from pathlib import Path

# Import rubric validation from batch_evaluate
from batch_evaluate import validate_all_rubrics

def count_running_screens(repo_names, session_code):
    """
    Count how many screens are still running for our repositories.
    
    Args:
        repo_names: List of repository names to check
        session_code: Unique session identifier to filter our screens
        
    Returns:
        tuple: (success, running_count, running_repos, finished_repos)
        success: bool - True if check was successful, False if there was an error
    """
    try:
        # Get list of all active screens
        result = subprocess.run(['screen', '-ls'], capture_output=True, text=True)
        screen_output = result.stdout
        
        running_repos = []
        finished_repos = []
        
        for repo in repo_names:
            # Look for our specific repo screen session with session code
            # screen -ls output format is typically: "PID.session_name"
            screen_name = f"{session_code}_{repo}"
            if f".{screen_name}\t" in screen_output or f".{screen_name} " in screen_output:
                running_repos.append(repo)
            else:
                finished_repos.append(repo)
        
        return True, len(running_repos), running_repos, finished_repos
        
    except FileNotFoundError:
        print("Warning: 'screen' command not found. Cannot check running screens.")
        return False, 0, [], repo_names
    except subprocess.CalledProcessError:
        # screen -ls returns non-zero when no screens are running
        return True, 0, [], repo_names

def wait_for_batch_completion(batch_repos, session_code, check_interval=30):
    """
    Wait for all screens in a batch to complete.
    
    Args:
        batch_repos: List of repository names in the current batch
        session_code: Unique session identifier
        check_interval: How often to check (in seconds)
    """
    print(f"⏳ Waiting for batch of {len(batch_repos)} repositories to complete...")
    start_time = time.time()
    
    while True:
        success, running_count, running_repos, finished_repos = count_running_screens(batch_repos, session_code)
        
        if not success:
            print(f"Cannot check screen status. Will retry in {check_interval}s...")
            time.sleep(check_interval)
            continue
        
        if running_count == 0:
            elapsed = time.time() - start_time
            print(f"Batch completed in {elapsed:.1f}s. All {len(batch_repos)} repositories finished.")
            break
        
        elapsed = time.time() - start_time
        print(f"[{elapsed:.0f}s] Still running: {running_count}/{len(batch_repos)} - {', '.join(running_repos)}")
        time.sleep(check_interval)

def clean_docker_system():
    """
    Clean Docker system to free up disk space and resources.
    """
    print("🧹 Cleaning Docker system...")
    try:
        result = subprocess.run(
            ['docker', 'system', 'prune', '-a', '--volumes', '-f'],
            capture_output=True, text=True, check=True
        )
        print("✅ Docker cleanup completed successfully.")
        # Print any useful output from the cleanup
        if result.stdout.strip():
            print(f"   Output: {result.stdout.strip()}")
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Docker cleanup failed: {e}")
        print(f"   Error output: {e.stderr}")
    except FileNotFoundError:
        print("⚠️  Docker command not found. Skipping cleanup.")

def launch_batch(batch_repos, session_code, rubric_dir):
    """
    Launch screen sessions for a batch of repositories.
    
    Args:
        batch_repos: List of repository names to launch
        session_code: Unique session identifier
        rubric_dir: Path to rubrics directory
        
    Returns:
        List of successfully launched repositories
    """
    launched_repos = []
    
    for repo in batch_repos:
        screen_name = f"{session_code}_{repo}"
        print(f"  Starting screen for {repo} (session: {screen_name})...")
        
        cmd = [
            "screen", "-dmS", screen_name, "bash", "-c",
            f"python3 batch_evaluate.py --skip-warnings --verbose --rubric-dir '{rubric_dir}' --repo '{repo}'"
        ]
        
        try:
            subprocess.run(cmd, check=True)
            print(f"    → Screen '{screen_name}' started.")
            launched_repos.append(repo)
        except subprocess.CalledProcessError as e:
            print(f"    ✗ Failed to start screen for '{repo}': {e}")
        except FileNotFoundError:
            print("    ✗ Error: 'screen' command not found. Please install screen or use an alternative.")
            sys.exit(1)
    
    return launched_repos

def main():
    parser = argparse.ArgumentParser(description="Launch batch evaluation for repositories with resource management")
    parser.add_argument('--batch-size', '-k', type=int, default=8, 
                       help='Number of repositories to process simultaneously (default: 8)')
    parser.add_argument('--check-interval', type=int, default=30,
                       help='How often to check for completion in seconds (default: 30)')
    parser.add_argument('--skip-docker-cleanup', action='store_true',
                       help='Skip Docker system cleanup between batches')
    parser.add_argument('--rubric-dir', type=str, default='rubrics/manual',
                       help='Directory containing rubric JSON files (default: rubrics/manual)')
    
    args = parser.parse_args()
    
    # Generate unique session code for this batch run
    timestamp = int(time.time())
    random_id = random.randint(1000, 9999)
    session_code = f"eval_{timestamp}_{random_id}"
    
    print(f"🚀 Starting batched evaluation with session code: {session_code}")
    print(f"📦 Batch size: {args.batch_size} repositories at a time")
    print(f"⏱️  Check interval: {args.check_interval}s")
    print(f"📁 Rubric directory: {args.rubric_dir}")
    print()
    
    # Directory containing the rubric JSON files
    rubric_dir = args.rubric_dir
    
    # Check if rubric directory exists
    if not os.path.exists(rubric_dir):
        print(f"Error: Rubric directory '{rubric_dir}' not found!")
        sys.exit(1)
    
    # Find all .json files and extract repo names (without .json extension)
    json_pattern = os.path.join(rubric_dir, "*.json")
    json_files = glob.glob(json_pattern)
    
    if not json_files:
        print(f"No JSON files found in '{rubric_dir}'")
        sys.exit(1)
    
    # Extract repo names by removing .json extension
    all_repos = [Path(f).stem for f in json_files]
    
    print(f"Found {len(all_repos)} repos:")
    for repo in all_repos:
        print(f"  - {repo}")
    print()
    
    # Validate rubrics for all repositories before starting evaluations
    print("Validating rubrics for all repositories...")
    validation_results = validate_all_rubrics(all_repos, rubric_dir)
    problematic = {r: errs for r, errs in validation_results.items() if errs}
    
    if problematic:
        print("\nERROR: Rubric validation failed for the following repositories:")
        total_issues = 0
        for r, errs in problematic.items():
            print(f"\n- {r}:")
            for e in errs:
                print(f"    - {e}")
            total_issues += len(errs)
        
        print(f"\nFound {len(problematic)} problematic rubric(s) with {total_issues} issue(s).")
        print("Please fix the above rubric files and re-run the batch evaluation.")
        sys.exit(2)
    
    print("All rubrics validated successfully!")
    print()
    
    # Process repositories in batches
    total_batches = (len(all_repos) + args.batch_size - 1) // args.batch_size
    completed_repos = []
    
    for batch_num in range(total_batches):
        start_idx = batch_num * args.batch_size
        end_idx = min(start_idx + args.batch_size, len(all_repos))
        batch_repos = all_repos[start_idx:end_idx]
        
        print(f"🔄 Starting batch {batch_num + 1}/{total_batches} ({len(batch_repos)} repositories)")
        print(f"   Repositories: {', '.join(batch_repos)}")
        
        # Launch batch
        launched_repos = launch_batch(batch_repos, session_code, rubric_dir)
        
        if not launched_repos:
            print(f"⚠️  No repositories were successfully launched in batch {batch_num + 1}")
            continue
        
        print(f"✅ Batch {batch_num + 1} launched: {len(launched_repos)} screens started")
        
        # Wait for batch to complete
        time.sleep(5)  # Short delay before checking
        wait_for_batch_completion(launched_repos, session_code, args.check_interval)
        completed_repos.extend(launched_repos)
        
        # Clean Docker system between batches
        if not args.skip_docker_cleanup:
            time.sleep(5)  # Short delay before cleaning
            clean_docker_system()
            print()  # Add spacing before next batch
    
    # Final summary
    print()
    print("🎉 All batches completed!")
    print(f"📊 Final Summary:")
    print(f"  Total repositories processed: {len(completed_repos)}/{len(all_repos)}")
    print(f"  Session code: {session_code}")
    
    if len(completed_repos) < len(all_repos):
        failed_repos = set(all_repos) - set(completed_repos)
        print(f"  Failed to process: {', '.join(failed_repos)}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error occurred: {e}.\nCleaning up Docker system...")
        try:
            clean_docker_system()
            print("Cleanup completed.")
        except Exception as cleanup_error:
            print(f"Error occurred during cleanup: {cleanup_error}")
        