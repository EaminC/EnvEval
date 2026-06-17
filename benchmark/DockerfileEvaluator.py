#!/usr/bin/env python3
"""
Dockerfile Evaluation Script

This script evaluates machine-generated Dockerfiles by:
1. Building the Docker container from the provided Dockerfile
2. Loading test specifications from a JSON rubric file
3. Running tests inside the container and scoring them (1 for pass, 0 for fail)

Usage:
    python DockerfileEvaluator.py --dockerfile <path> --repo <name> [--rubric <path>] [--output <path>] [--verbose]
"""

import argparse
import json
import random
import subprocess
import sys
import tempfile
import time
import os
import re
import shutil
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from pathlib import Path


@dataclass
class TestResult:
    """Represents the result of a single test"""
    test_id: str
    test_type: str
    n_passed: int
    score: float
    message: str
    execution_time: float
    n_tests: int = 1  # Default to 1 test per result


class DockerfileEvaluator:
    """Main class for evaluating Dockerfiles using JSON rubrics"""

    def __init__(self, repo_name: str, dockerfile_path: str, rubric_dir: str = "rubrics/manual", skip_warnings: bool = False):
        self.repo_name = repo_name
        self.dockerfile_path = Path(dockerfile_path)
        self.rubric_path = Path(f"{rubric_dir}/{repo_name}.json")
        self.skip_warnings = skip_warnings
        # Use more precise timestamp + random suffix to avoid conflicts
        timestamp = int(time.time() * 1000)  # milliseconds for better precision
        random_suffix = random.randint(1000, 9999)
        self.container_name = f"eval_{repo_name.lower()}_{timestamp}_{random_suffix}"
        self.image_name = f"eval_{repo_name.lower()}:{timestamp}_{random_suffix}"
        self.results: List[TestResult] = []
        self.tests: List[Dict[str, Any]] = []
        self.build_log: Dict[str, Any] = {}  # Store detailed build information
        self.running_container_id: Optional[str] = None  # Track running container
        
    def load_rubric(self) -> Dict[str, Any]:
        """Load and parse the JSON rubric file"""
        try:
            with open(self.rubric_path, 'r') as f:
                rubric = json.load(f)
            print(f"Loaded rubric for repo: {rubric.get('repo', 'unknown')}")
            return rubric
        except FileNotFoundError:
            print(f"Error: Rubric file not found: {self.rubric_path}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in rubric file: {e}")
            sys.exit(1)
    
    def build_docker_image(self) -> bool:
        """Build Docker image from the provided Dockerfile"""
        print(f"Building Docker image: {self.image_name}")
        
        # Check if there's source code in data/{repo} directory
        repo_data_path = Path(f"data/{self.repo_name}")
        copied_repo_path = None
        copied_dockerfile_path = None
        
        try:
            # Get dockerfile directory
            dockerfile_dir = self.dockerfile_path.parent
            
            # Determine scenario based on dockerfile path structure
            # Scenario 1: path/envgym.dockerfile
            # Scenario 2: path/envgym/envgym.dockerfile
            is_scenario_2 = dockerfile_dir.name == "envgym"
            
            # Copy repo directory to dockerfile directory if it exists
            if repo_data_path.exists() and repo_data_path.is_dir():
                print(f"Found source code directory: {repo_data_path}")
                
                if is_scenario_2:
                    # Scenario 2: Flatten structure
                    # Copy repo files directly to parent of envgym/ directory
                    target_dir = dockerfile_dir.parent  # Go up from envgym/ to get path/
                    print(f"Scenario 2: Copying repo files to {target_dir} (outside envgym/)")
                    
                    # Issue warning and ask for permission before clearing directory
                    if not self.skip_warnings:
                        print(f"\nWARNING: About to clear directory '{target_dir}' while preserving the 'envgym/' folder.")
                        print("This will remove all existing files and directories in the target location except 'envgym/'.")
                        response = input("Do you want to proceed? (y/N): ").strip().lower()
                        
                        if response not in ['y', 'yes']:
                            print("Operation cancelled by user.")
                            return False
                    else:
                        print(f"\nSkipping warnings: Clearing directory '{target_dir}' while preserving the 'envgym/' folder.")
                    
                    # First, clear out the parent directory except the envgym folder
                    print(f"Clearing target directory while preserving envgym/ folder")
                    for item in target_dir.iterdir():
                        if item.name != "envgym":  # Preserve the envgym folder
                            if item.is_dir():
                                shutil.rmtree(item)
                            else:
                                item.unlink()
                    
                    # Copy all files from data/repo_name/* to target_dir/
                    for item in repo_data_path.iterdir():
                        dest_path = target_dir / item.name
                        if item.is_dir():
                            shutil.copytree(item, dest_path)
                        else:
                            shutil.copy2(item, dest_path)
                    
                    print(f"Copied repo files from {repo_data_path} to {target_dir}")
                    
                    # Use original dockerfile path and set build context to parent of envgym/
                    dockerfile_to_use = str(self.dockerfile_path)
                    build_context = str(target_dir)
                    copied_repo_path = target_dir  # For cleanup tracking
                    
                else:
                    # Scenario 1: Create nested structure (existing logic)
                    print(f"Scenario 1: Creating nested structure")
                    
                    # Define destination path in dockerfile directory
                    copied_repo_path = dockerfile_dir / self.repo_name
                    
                    # Remove existing directory if it exists
                    if copied_repo_path.exists():
                        shutil.rmtree(copied_repo_path)
                    
                    # Copy the entire repo directory to the outer repo_name folder
                    shutil.copytree(repo_data_path, copied_repo_path)
                    print(f"Copied {repo_data_path} to {copied_repo_path}")
                    
                    # Create nested repo directory inside the copied repo directory
                    # Check if nested path would conflict with existing directory
                    nested_repo_path = copied_repo_path / self.repo_name
                    if nested_repo_path.exists():
                        print(f"Skipping nested repo creation - directory already exists at {nested_repo_path}")
                    else:
                        shutil.copytree(repo_data_path, nested_repo_path)
                        print(f"Created nested repo structure at {nested_repo_path}")
                    
                    # Copy dockerfile into the repo directory
                    copied_dockerfile_path = copied_repo_path / self.dockerfile_path.name
                    shutil.copy2(self.dockerfile_path, copied_dockerfile_path)
                    print(f"Copied dockerfile to {copied_dockerfile_path}")
                    
                    # Use the copied dockerfile
                    dockerfile_to_use = str(copied_dockerfile_path)
                    
                    # Set build context to the copied repo directory
                    build_context = str(copied_repo_path)
                
            else:
                if not repo_data_path.exists():
                    raise FileNotFoundError(f"Error: Source code directory not found at {repo_data_path}. Please check that the repo parameter '{self.repo_name}' is correct.")
            
            cmd = [
                "docker", "build", 
                "--no-cache",
                "--network", "host",
                "--label", f"uuid={self.container_name}",
                "-t", self.image_name,
                "-f", dockerfile_to_use,
                build_context
            ]
            print(f"Running command: {' '.join(cmd)}")
            
            # Store build command and context info in build_log
            self.build_log = {
                "command": " ".join(cmd),
                "dockerfile_path": dockerfile_to_use,
                "build_context": build_context,
                "scenario": "scenario_2" if is_scenario_2 else "scenario_1",
                "repo_data_exists": repo_data_path.exists(),
                "build_success": False,
                "build_stdout": "",
                "build_stderr": "",
                "build_returncode": None,
                "build_timeout": False,
                "error_message": None
            }
            
            result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=3600)
            
            # Store detailed build results
            self.build_log["build_returncode"] = result.returncode
            self.build_log["build_stdout"] = result.stdout
            self.build_log["build_stderr"] = result.stderr
            
            if result.returncode == 0:
                self.build_log["build_success"] = True
                print("PASS: Docker image built successfully")
                return True
            else:
                self.build_log["error_message"] = f"Docker build failed with return code {result.returncode}"
                print(f"FAIL: Failed to build Docker image:")
                print(f"STDOUT: {result.stdout}")
                print(f"STDERR: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.build_log["build_timeout"] = True
            self.build_log["error_message"] = "Docker build timed out (60 minutes)"
            print("FAIL: Docker build timed out (60 minutes)")
            return False
        except Exception as e:
            self.build_log["error_message"] = f"Error building Docker image: {str(e)}"
            print(f"FAIL: Error building Docker image: {e}")
            return False
        finally:
            # Clean up copied repo directory and dockerfile
            if copied_repo_path and copied_repo_path.exists():
                try:
                    if is_scenario_2:
                        # Scenario 2: Clean up individual files/folders copied to target_dir
                        # Only remove items that were copied from repo_data_path, making it safer
                        for item in repo_data_path.iterdir():
                            item_to_remove = copied_repo_path / item.name
                            if item_to_remove.exists():
                                if item_to_remove.is_dir():
                                    shutil.rmtree(item_to_remove)
                                else:
                                    item_to_remove.unlink()
                        print(f"Cleaned up copied repo files from: {copied_repo_path}")
                    else:
                        # Scenario 1: Remove the entire copied repo directory
                        shutil.rmtree(copied_repo_path)
                        print(f"Cleaned up copied repo directory: {copied_repo_path}")
                except Exception as e:
                    print(f"Warning: Could not clean up copied repo directory: {e}")
            
            # Note: copied_dockerfile_path cleanup is handled by removing the parent directory
    
    def start_container(self) -> bool:
        """Start a persistent container for running tests"""
        try:
            # Clean up any existing container with the same name first
            subprocess.run(["docker", "rm", "-f", self.container_name], 
                         capture_output=True, check=False)
            
            cmd = [
                "docker", "run", "-d",
                "--label", f"uuid={self.container_name}",
                "--name", self.container_name,
                "--restart", "unless-stopped",  # Auto-restart if container stops unexpectedly
                self.image_name,
                "sleep", "infinity"  # Keep container running indefinitely
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
            
            if result.returncode == 0:
                self.running_container_id = result.stdout.strip()
                print(f"Started persistent container: {self.container_name}")
                
                # Wait for container to be fully ready (handles restart policies)
                if self.wait_for_container_ready():
                    return True
                else:
                    print(f"Container started but failed to become ready")
                    return False
            else:
                print(f"Failed to start container: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"Error starting container: {e}")
            return False
    
    def stop_container(self):
        """Stop and remove the persistent container"""
        if self.running_container_id:
            try:
                # First try to stop gracefully with timeout
                stop_result = subprocess.run(["docker", "stop", "-t", "10", self.container_name],
                                           capture_output=True, text=True, check=False)
                
                # Force kill if graceful stop failed
                if stop_result.returncode != 0:
                    print(f"Graceful stop failed, force killing container: {self.container_name}")
                    subprocess.run(["docker", "kill", self.container_name],
                                 capture_output=True, check=False)
                
                # Use -f to force remove and -v to remove any anonymous volumes attached to the container
                rm_result = subprocess.run(["docker", "rm", "-f", "-v", self.container_name],
                                         capture_output=True, text=True, check=False)
                
                if rm_result.returncode == 0:
                    print(f"Stopped and removed persistent container (and anonymous volumes): {self.container_name}")
                else:
                    print(f"Warning: Failed to remove container {self.container_name}: {rm_result.stderr}")
                    
                self.running_container_id = None
            except Exception as e:
                print(f"Warning: Could not stop container: {e}")
                # Still clear the ID to prevent future attempts
                self.running_container_id = None
    
    def wait_for_container_ready(self, timeout_seconds: int = 300) -> bool:
        """Wait for container to be ready (not restarting or starting)"""
        import time
        
        start_time = time.time()
        retry_interval = 30  # Wait 30 seconds between checks
        
        while time.time() - start_time < timeout_seconds:
            try:
                # Check container state
                result = subprocess.run(
                    ["docker", "inspect", "-f", "{{.State.Status}}", self.container_name],
                    capture_output=True, text=True, check=False
                )
                
                if result.returncode == 0:
                    status = result.stdout.strip().lower()
                    print(f"Container {self.container_name} status: {status}")
                    
                    if status == "running":
                        # Double-check that it's actually responsive
                        test_result = subprocess.run(
                            ["docker", "exec", self.container_name, "echo", "test"],
                            capture_output=True, text=True, check=False, timeout=10
                        )
                        if test_result.returncode == 0:
                            print(f"Container {self.container_name} is ready and responsive")
                            return True
                        else:
                            print(f"Container {self.container_name} is running but not responsive yet")
                    elif status in ["restarting", "starting"]:
                        elapsed = int(time.time() - start_time)
                        print(f"Container {self.container_name} is {status}, waiting... ({elapsed}s elapsed)")
                    elif status in ["exited", "dead"]:
                        print(f"Container {self.container_name} has {status}, restart failed")
                        return False
                else:
                    print(f"Failed to check container status: {result.stderr}")
                    
            except subprocess.TimeoutExpired:
                print(f"Container exec test timed out, container may still be starting")
            except Exception as e:
                print(f"Error checking container status: {e}")
            
            # Wait before next check
            time.sleep(retry_interval)
        
        print(f"Timeout waiting for container {self.container_name} to be ready after {timeout_seconds}s")
        return False
    
    def is_container_running(self) -> bool:
        """Check if the container is actually running"""
        if not self.running_container_id:
            return False
            
        try:
            result = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Running}}", self.container_name],
                capture_output=True, text=True, check=False
            )
            return result.returncode == 0 and result.stdout.strip().lower() == "true"
        except Exception:
            return False
    
    def ensure_container_running(self) -> bool:
        """Ensure container is running, restart if necessary"""
        if self.is_container_running():
            return True
            
        print(f"Container {self.container_name} is not running, checking status...")
        
        # Check if container is in a restarting state
        try:
            result = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Status}}", self.container_name],
                capture_output=True, text=True, check=False
            )
            
            if result.returncode == 0:
                status = result.stdout.strip().lower()
                print(f"Container status: {status}")
                
                if status in ["restarting", "starting"]:
                    print(f"Container is {status}, waiting for it to be ready...")
                    return self.wait_for_container_ready()
                elif status == "exited":
                    print(f"Container has exited, attempting to restart...")
                    # Try to start the existing container
                    restart_result = subprocess.run(
                        ["docker", "start", self.container_name],
                        capture_output=True, text=True, check=False
                    )
                    if restart_result.returncode == 0:
                        print(f"Container start command successful, waiting for ready state...")
                        return self.wait_for_container_ready()
        except Exception as e:
            print(f"Error checking container status: {e}")
        
        # If all else fails, create a new container
        print(f"Could not restart existing container, creating new one...")
        
        # Clean up the old container
        try:
            subprocess.run(["docker", "rm", "-f", self.container_name], 
                         capture_output=True, check=False)
        except Exception:
            pass
            
        # Start a new container
        return self.start_container()
    
    def run_docker_command(self, command: str, timeout: int = -1):
        """Run a command inside the persistent Docker container with automatic recovery"""
        if not self.running_container_id:
            return False, "", "No running container available"
        
        # Ensure container is running before executing command
        if not self.ensure_container_running():
            return False, "", "Could not ensure container is running"
            
        max_retries = 2
        for attempt in range(max_retries):
            try:
                cmd = [
                    "docker", "exec",
                    self.container_name,
                    "sh", "-c", command
                ]
                
                if timeout != -1:
                    result = subprocess.run(
                        cmd,
                        capture_output=True,
                        text=True,
                        encoding='utf-8',
                        errors='replace',
                        timeout=timeout
                    )
                else:
                    result = subprocess.run(
                        cmd,
                        capture_output=True,
                        text=True,
                        encoding='utf-8',
                        errors='replace'
                    )            
                success = result.returncode == 0
                return success, result.stdout, result.stderr
                
            except subprocess.TimeoutExpired:
                return False, "", f"Command timed out ({timeout}s)"
            except Exception as e:
                error_msg = str(e)
                
                # Check if this is a container issue that requires waiting/recovery
                if any(phrase in error_msg.lower() for phrase in ["is not running", "is restarting", "wait until"]) and attempt < max_retries - 1:
                    print(f"Container issue detected: {error_msg}")
                    print(f"Attempting recovery (attempt {attempt + 1}/{max_retries})...")
                    
                    if not self.ensure_container_running():
                        return False, "", "Could not recover container after failure"
                    
                    # Additional wait to ensure container is fully ready
                    if not self.wait_for_container_ready(120):  # Shorter timeout for retries
                        return False, "", "Container not ready after recovery attempt"
                    
                    continue
                    
                return False, "", error_msg
                
        return False, "", "Failed after all retry attempts"
    
    def test_commands_exist(self, test: Dict[str, Any]) -> TestResult:
        """Test if commands exist in the container with proportional scoring"""
        start_time = time.time()
        params = test.get('params', {})
        command_names = params.get('names', [])
        test_id = test.get('id', f"commands_exist_{hash(tuple(command_names))}")
        
        if not command_names:
            execution_time = time.time() - start_time
            return TestResult(test_id, "commands_exist", 0, 0, 
                            "No commands specified", execution_time)
        
        found_commands = []
        missing_commands = []
        
        for command_name in command_names:
            success, stdout, stderr = self.run_docker_command(f"command -v {command_name}")
            if success and stdout.strip() != "":
                found_commands.append(command_name)
            else:
                missing_commands.append(command_name)
        
        execution_time = time.time() - start_time
        score = test.get('score', 1) * (len(found_commands) / len(command_names))
        n_passed = len(found_commands)
        
        if n_passed == len(command_names):
            message = f"All commands found: {', '.join(found_commands)}"
        elif found_commands:
            message = f"Found {len(found_commands)}/{len(command_names)} commands. Found: {', '.join(found_commands)}. Missing: {', '.join(missing_commands)}"
        else:
            message = f"No commands found. Missing: {', '.join(missing_commands)}"
        
        return TestResult(test_id, "commands_exist", n_passed, score, message, execution_time, n_tests=len(command_names))
    
    def test_output_contains(self, test: Dict[str, Any]) -> TestResult:
        """Test if command output contains specific strings"""
        start_time = time.time()
        params = test.get('params', {})
        command = params.get('command', '')
        contains_list = params.get('contains', [])
        timeout = test.get('timeout', 30)
        test_id = test.get('id', f"output_contains_{hash(command)}")
        test_score = test.get('score', 1)
        
        success, stdout, stderr = self.run_docker_command(command, timeout)
        
        execution_time = time.time() - start_time
        
        # Check if any of the required strings are in the output
        output_text = stdout + stderr
        found_matches = [item for item in contains_list if str(item) in output_text]
        n_passed = int(len(found_matches) > 0)
        score = test_score if n_passed else 0
        
        '''
        # Truncate output for logging (first 200 chars)
        output_preview = output_text.replace('\n', ' ').strip()[:200]
        if len(output_text) > 200:
            output_preview += "..."
        '''
        
        if n_passed:
            message = f"Output contains: {', '.join(map(str, found_matches))}."
        else:
            message = f"Output does not contain any of: {', '.join(map(str, contains_list))}. Command output: {output_text}"
        
        return TestResult(test_id, "output_contains", n_passed, score, message, execution_time)
    
    def test_files_exist(self, test: Dict[str, Any]) -> TestResult:
        """Test if files exist in the container"""
        start_time = time.time()
        params = test.get('params', {})
        file_paths = params.get('paths', [])
        test_id = test.get('id', f"files_exist_{hash(tuple(file_paths))}")
        test_score = test.get('score', 1)

        found_files = []
        missing_files = []
        
        for file_path in file_paths:
            success, stdout, stderr = self.run_docker_command(f"test -f '{file_path}'")
            if success:
                found_files.append(file_path)
            else:
                missing_files.append(file_path)
        
        execution_time = time.time() - start_time
        n_passed = len(found_files)
        score = test_score * (n_passed / len(file_paths)) if file_paths else 0
        
        if n_passed == len(file_paths):
            message = f"All files found: {', '.join(found_files)}"
        elif found_files:
            message = f"Found {len(found_files)}/{len(file_paths)} files. Found: {', '.join(found_files)}. Missing: {', '.join(missing_files)}"
        else:
            message = f"No files found. Missing: {', '.join(missing_files)}"

        return TestResult(test_id, "files_exist", n_passed, score, message, execution_time, n_tests=len(file_paths))

    def test_dirs_exist(self, test: Dict[str, Any]) -> TestResult:
        """Test if a directory exists in the container"""
        start_time = time.time()
        params = test.get('params', {})
        dir_paths = params.get('paths', [])
        test_id = test.get('id', f"dirs_exist_{hash(tuple(dir_paths))}")
        test_score = test.get('score', 1)

        found_dirs = []
        missing_dirs = []
        
        for dir_path in dir_paths:
            success, stdout, stderr = self.run_docker_command(f"test -d '{dir_path}'")
            if success:
                found_dirs.append(dir_path)
            else:
                missing_dirs.append(dir_path)
        
        execution_time = time.time() - start_time
        n_passed = len(found_dirs)
        score = test_score * (n_passed / len(dir_paths)) if dir_paths else 0
        
        if n_passed == len(dir_paths):
            message = f"All directories found: {', '.join(found_dirs)}"
        elif found_dirs:
            message = f"Found {len(found_dirs)}/{len(dir_paths)} directories. Found: {', '.join(found_dirs)}. Missing: {', '.join(missing_dirs)}"
        else:
            message = f"No directories found. Missing: {', '.join(missing_dirs)}"

        return TestResult(test_id, "dirs_exist", n_passed, score, message, execution_time, n_tests=len(dir_paths))

    def test_envvar_set(self, test: Dict[str, Any]) -> TestResult:
        """Test if an environment variable is set"""
        start_time = time.time()
        params = test.get('params', {})
        var_name = params.get('name', '')
        test_id = test.get('id', f"envvar_set_{var_name}")
        test_score = test.get('score', 1)
        
        success, stdout, stderr = self.run_docker_command(f"test -n \"${var_name}\"")
        
        execution_time = time.time() - start_time
        passed = success
        score = test_score if passed else 0
        message = f"Environment variable '{var_name}' {'is set' if passed else 'is not set'}"
        
        return TestResult(test_id, "envvar_set", passed, score, message, execution_time)
    
    def test_file_contains(self, test: Dict[str, Any]) -> TestResult:
        """Test if a file contains specific strings"""
        start_time = time.time()
        params = test.get('params', {})
        file_path = params.get('path', '')
        contains_list = params.get('contains', [])
        test_id = test.get('id', f"file_contains_{hash(file_path)}")
        test_score = test.get('score', 1)
        
        # First check if file exists
        success, stdout, stderr = self.run_docker_command(f"test -f '{file_path}'")
        if not success:
            execution_time = time.time() - start_time
            return TestResult(test_id, "file_contains", False, 0, 
                            f"File '{file_path}' does not exist", execution_time)
        
        # Read file content
        success, stdout, stderr = self.run_docker_command(f"cat '{file_path}'")
        execution_time = time.time() - start_time
        
        if not success:
            return TestResult(test_id, "file_contains", 0, 0, 
                            f"Could not read file '{file_path}': {stderr}", execution_time)
        
        # Check if any of the required strings are in the file
        file_content = stdout
        found_matches = [item for item in contains_list if str(item) in file_content]
        passed = len(found_matches) > 0
        score = test_score if passed else 0
        
        if passed:
            message = f"File contains: {', '.join(map(str, found_matches))}"
        else:
            message = f"File does not contain any of: {', '.join(map(str, contains_list))}"
        
        return TestResult(test_id, "file_contains", int(passed), score, message, execution_time)
    
    def test_run_command(self, test: Dict[str, Any]) -> TestResult:
        """Test if a command runs successfully"""
        start_time = time.time()
        params = test.get('params', {})
        command = params.get('command', '')
        timeout = test.get('timeout', 30)
        test_id = test.get('id', f"run_command_{hash(command)}")
        test_score = test.get('score', 1)
        
        success, stdout, stderr = self.run_docker_command(command, timeout)
        
        execution_time = time.time() - start_time
        passed = success
        score = test_score if passed else 0
        
        # Truncate output for logging (first 200 chars)
        output_text = stdout + stderr
        '''
        output_preview = output_text.replace('\n', ' ').strip()[:200]
        if len(output_text) > 200:
            output_preview += "..."
        '''
        
        if passed:
            message = f"Command executed successfully."
        else:
            message = f"Command failed. Output: {output_text}"
        
        return TestResult(test_id, "run_command", int(passed), score, message, execution_time)
    
    def can_run_test(self, test: Dict[str, Any], completed_tests: Dict[str, TestResult]) -> bool:
        """Check if a test's requirements are met"""
        print("WARNING: requirements checking is deprecated, all tests will be run in order. Behavior should be the same, because tests whose requirements failed should fail as well.")
        return True
    
    def run_single_test(self, test: Dict[str, Any]) -> TestResult:
        """Run a single test based on its type"""
        test_type = test.get('type', '')
        
        test_methods = {
            'commands_exist': self.test_commands_exist,
            'output_contains': self.test_output_contains,
            'files_exist': self.test_files_exist,
            'dirs_exist': self.test_dirs_exist,
            'envvar_set': self.test_envvar_set,
            'file_contains': self.test_file_contains,
            'run_command': self.test_run_command,
        }
        
        if test_type in test_methods:
            return test_methods[test_type](test)
        else:
            test_id = test.get('id', f"unknown_{hash(str(test))}")
            return TestResult(test_id, test_type, False, 0, 
                            f"Unknown test type: {test_type}", 0.0)
    
    def run_tests(self, tests: List[Dict[str, Any]]) -> List[TestResult]:
        """Run all tests, respecting dependencies"""
        completed_tests: Dict[str, TestResult] = {}
        remaining_tests = tests.copy()
        max_iterations = len(tests) * 2  # Prevent infinite loops
        iteration = 0
        
        while remaining_tests and iteration < max_iterations:
            iteration += 1
            tests_to_remove = []
            
            for i, test in enumerate(remaining_tests):
                if self.can_run_test(test, completed_tests):
                    print(f"Running test: {test.get('type', 'unknown')}")
                    result = self.run_single_test(test)
                    self.results.append(result)
                    completed_tests[result.test_id] = result
                    tests_to_remove.append(i)
                    
                    # Print result
                    status = "✓" if result.n_passed else "✗"
                    print(f"  {status} {result.message} ({result.execution_time:.2f}s)")
            
            # Remove completed tests (in reverse order to maintain indices)
            for i in reversed(tests_to_remove):
                remaining_tests.pop(i)
            
            # If no tests were completed in this iteration, we have unresolvable dependencies
            if not tests_to_remove and remaining_tests:
                print("Warning: Some tests have unresolvable dependencies:")
                for test in remaining_tests:
                    test_id = test.get('id', f"unknown_{hash(str(test))}")
                    requires = test.get('requires', [])
                    result = TestResult(test_id, test.get('type', 'unknown'), False, 0,
                                      f"Unresolvable dependencies: {requires}", 0.0)
                    self.results.append(result)
                break
        
        return self.results
    
    def cleanup(self):
        """Clean up Docker resources"""
        # Use label filter to target only resources created by this evaluator run
        label_key = "uuid"
        label_value = self.container_name
        
        # Setup cleanup warnings log
        cleanup_warnings_dir = Path("cleanup_warnings")
        cleanup_warnings_dir.mkdir(exist_ok=True)
        log_file = cleanup_warnings_dir / f"{self.repo_name}.log"
        
        def log_warning(message: str):
            """Log warning to both file and console"""
            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
            log_entry = f"[{timestamp}] {message}\n"
            try:
                with open(log_file, 'a', encoding='utf-8') as f:
                    f.write(log_entry)
            except Exception as e:
                print(f"Warning: Could not write to cleanup log: {e}")
            print(f"  - Warning logged to {log_file}: {message}")
        
        try:
            # 1. Ensure persistent container is stopped (redundant but safe)
            if self.running_container_id:
                self.stop_container()

            # 2. Clean up any leftover containers from previous runs using multiple filters
            # First try by label
            result = subprocess.run(
                ["docker", "ps", "-a", "--filter", f"label={label_key}={label_value}", "--format", "{{.ID}}"],
                capture_output=True, text=True, check=False
            )
            container_ids_by_label = set()
            if result.returncode == 0 and result.stdout.strip():
                container_ids_by_label = set(c.strip() for c in result.stdout.strip().splitlines() if c.strip())
            
            # Also try by name pattern as fallback
            result = subprocess.run(
                ["docker", "ps", "-a", "--filter", f"name={self.container_name}", "--format", "{{.ID}}"],
                capture_output=True, text=True, check=False
            )
            container_ids_by_name = set()
            if result.returncode == 0 and result.stdout.strip():
                container_ids_by_name = set(c.strip() for c in result.stdout.strip().splitlines() if c.strip())
            
            # Combine both sets
            all_container_ids = container_ids_by_label | container_ids_by_name
            
            if all_container_ids:
                for cid in all_container_ids:
                    # Validate that this looks like a Docker container ID (12+ hex chars)
                    if len(cid) >= 12 and all(c in '0123456789abcdef' for c in cid.lower()):
                        # Stop with timeout (ignore errors) and remove with -f -v to clear anonymous volumes
                        subprocess.run(["docker", "stop", "-t", "5", cid], capture_output=True, check=False)
                        rm_result = subprocess.run(["docker", "rm", "-f", "-v", cid], capture_output=True, check=False)
                        if rm_result.returncode == 0:
                            print(f"  - Cleaned up leftover container: {cid}")
                        else:
                            log_warning(f"Failed to remove container {cid}: {rm_result.stderr.strip()}")
                    else:
                        log_warning(f"Skipped invalid container ID: {cid}")
            elif result.stderr.strip():
                log_warning(f"Could not list containers: {result.stderr.strip()}")

            # 3. Remove images that have the label (safer than removing by name)
            img_result = subprocess.run(
                ["docker", "images", "--filter", f"label={label_key}={label_value}", "--format", "{{.ID}}"],
                capture_output=True, text=True, check=False
            )
            if img_result.returncode == 0 and img_result.stdout.strip():
                image_ids = [i.strip() for i in img_result.stdout.strip().splitlines() if i.strip()]
                for iid in image_ids:
                    # Validate that this looks like a Docker image ID (12+ hex chars)
                    if len(iid) >= 12 and all(c in '0123456789abcdef' for c in iid.lower()):
                        result = subprocess.run(["docker", "rmi", "-f", iid], capture_output=True, check=False)
                        if result.returncode == 0:
                            print(f"  - Removed image: {iid}")
                        else:
                            log_warning(f"Failed to remove image {iid}: {result.stderr.strip()}")
                    else:
                        log_warning(f"Skipped invalid image ID: {iid}")
            elif img_result.stderr.strip():
                log_warning(f"Could not list images: {img_result.stderr.strip()}")

            # 4. Remove volumes created by this job (if named or labeled)
            vol_result = subprocess.run(
                ["docker", "volume", "ls", "--filter", f"label={label_key}={label_value}", "--format", "{{.Name}}"],
                capture_output=True, text=True, check=False
            )
            if vol_result.returncode == 0 and vol_result.stdout.strip():
                volumes = [v.strip() for v in vol_result.stdout.strip().splitlines() if v.strip()]
                for vol in volumes:
                    # Basic validation: volume names shouldn't contain spaces or special chars
                    if vol and not any(c in vol for c in [' ', '\t', '\n', '|', ';', '&']):
                        rm_result = subprocess.run(["docker", "volume", "rm", "-f", vol], capture_output=True, check=False)
                        if rm_result.returncode == 0:
                            print(f"  - Removed volume: {vol}")
                        else:
                            log_warning(f"Failed to remove volume {vol}: {rm_result.stderr.strip()}")
                    else:
                        log_warning(f"Skipped invalid volume name: {vol}")
            elif vol_result.stderr.strip():
                log_warning(f"Could not list volumes: {vol_result.stderr.strip()}")

            # 5. Remove networks created for this job (if any were labeled)
            net_result = subprocess.run(
                ["docker", "network", "ls", "--filter", f"label={label_key}={label_value}", "--format", "{{.ID}}"],
                capture_output=True, text=True, check=False
            )
            if net_result.returncode == 0 and net_result.stdout.strip():
                networks = [n.strip() for n in net_result.stdout.strip().splitlines() if n.strip()]
                for net in networks:
                    # Validate that this looks like a Docker network ID (12+ hex chars)
                    if len(net) >= 12 and all(c in '0123456789abcdef' for c in net.lower()):
                        rm_result = subprocess.run(["docker", "network", "rm", net], capture_output=True, check=False)
                        if rm_result.returncode == 0:
                            print(f"  - Removed network: {net}")
                        else:
                            log_warning(f"Failed to remove network {net}: {rm_result.stderr.strip()}")
                    else:
                        log_warning(f"Skipped invalid network ID: {net}")
            elif net_result.stderr.strip():
                log_warning(f"Could not list networks: {net_result.stderr.strip()}")

            # 6. Clean up build cache for this job only (via label)
            subprocess.run(
                ["docker", "builder", "prune", "-f", "--filter", f"label={label_key}={label_value}"],
                capture_output=True, check=False
            )

            # 7. As a best-effort fallback, try to remove the image by name (legacy behavior)
            try:
                subprocess.run(["docker", "rmi", "-f", self.image_name], capture_output=True, check=False)
            except Exception:
                pass

            print(f"Cleaned up Docker resources for: {self.repo_name}")
        except Exception as e:
            log_warning(f"Could not clean up Docker resources: {e}")
    
    def generate_report(self) -> Dict[str, Any]:
        """Generate a summary report of all test results"""
        total_tests = sum(r.n_tests for r in self.results)
        passed_tests = sum(r.n_passed for r in self.results)
        total_score = sum(r.score for r in self.results)
        max_score = sum(test.get('score', 1) for test in self.tests)
        total_time = sum(r.execution_time for r in self.results)
        
        # Add container health information for debugging
        container_health = {
            "final_container_running": self.is_container_running(),
            "container_id": self.running_container_id,
            "container_name": self.container_name
        }
        
        report = {
            "repo": self.repo_name,
            "dockerfile": str(self.dockerfile_path),
            "rubric": str(self.rubric_path),
            "build_log": self.build_log,  # Include detailed build information
            "container_health": container_health,  # Add container health info
            "summary": {
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": total_tests - passed_tests,
                "total_score": total_score,
                "max_score": max_score,
                "success_rate": passed_tests / total_tests if total_tests > 0 else 0,
                "total_execution_time": total_time
            },
            "test_results": [
                {
                    "test_id": r.test_id,
                    "test_type": r.test_type,
                    "passed": r.n_passed,
                    "score": r.score,
                    "message": r.message,
                    "execution_time": r.execution_time
                }
                for r in self.results
            ]
        }
        
        return report
    
    def evaluate(self) -> Dict[str, Any]:
        """Main evaluation method"""
        print(f"Starting evaluation for repo: {self.repo_name}")
        print(f"Dockerfile: {self.dockerfile_path}")
        print(f"Rubric: {self.rubric_path}")
        print("-" * 50)
        
        # Load rubric
        rubric = self.load_rubric()
        tests = rubric.get('tests', [])
        self.tests = tests  # Store tests for report generation
        
        if not tests:
            print("No tests found in rubric")
            return self.generate_report()
        
        # Build Docker image
        if not self.build_docker_image():
            print("Failed to build Docker image, cannot run tests")
            return self.generate_report()
        
        # Start persistent container
        if not self.start_container():
            print("Failed to start container, cannot run tests")
            return self.generate_report()
        
        try:
            # Run tests
            print(f"\nRunning {len(tests)} tests...")
            self.run_tests(tests)
            
            # Generate and return report
            return self.generate_report()
            
        finally:
            # Always cleanup
            self.stop_container()
            self.cleanup()


def main():
    parser = argparse.ArgumentParser(description="Evaluate Dockerfiles using JSON rubrics")
    parser.add_argument("--dockerfile", required=True, help="Path to the Dockerfile to evaluate")
    parser.add_argument("--repo", required=True, help="Repository name")
    parser.add_argument("--rubric-dir", default="rubrics/manual", help="Directory containing rubric files")
    parser.add_argument("--output", help="Path to save the evaluation report JSON")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("--skip-warnings", action="store_true", help="Skip user confirmation prompts for potentially destructive operations, turn on with caution!")
    
    args = parser.parse_args()
    
    # Create evaluator
    evaluator = DockerfileEvaluator(args.repo, args.dockerfile, args.rubric_dir, args.skip_warnings)

    try:
        # Run evaluation
        report = evaluator.evaluate()
        
        # Print summary
        print("\n" + "=" * 50)
        print("EVALUATION SUMMARY")
        print("=" * 50)
        summary = report["summary"]
        print(f"Repository: {report['repo']}")
        print(f"Total Tests: {summary['total_tests']}")
        print(f"Passed: {summary['passed_tests']}")
        print(f"Failed: {summary['failed_tests']}")
        print(f"Score: {summary['total_score']}/{summary['max_score']}")
        print(f"Success Rate: {summary['success_rate']:.2%}")
        print(f"Total Time: {summary['total_execution_time']:.2f}s")
        
        # Save report if requested
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"\nReport saved to: {args.output}")
        
        # Print detailed results if verbose
        if args.verbose:
            print("\nDETAILED RESULTS:")
            print("-" * 50)
            for result in report["test_results"]:
                status = "PASS" if result["passed"] else "FAIL"
                print(f"{status} [{result['test_type']}] {result['message']} ({result['execution_time']:.2f}s)")
        
        # Exit with appropriate code
        sys.exit(0 if summary['failed_tests'] == 0 else 1)
        
    except KeyboardInterrupt:
        print("\nEvaluation interrupted by user")
        evaluator.cleanup()
        sys.exit(130)
    except Exception as e:
        print(f"Evaluation failed: {e}")
        evaluator.cleanup()
        sys.exit(1)


if __name__ == "__main__":
    main()
