# EnvEval Benchmark

Evaluation framework for machine-generated Dockerfiles that validates environment setup through automated testing.

## Overview

EnvEval consists of three main tools:
1. **DockerfileEvaluator.py** - Evaluates individual Dockerfiles using JSON-based rubrics
2. **batch_evaluate.py** - Batch evaluates multiple Dockerfiles and generates comparison reports
3. **generate_stats.py** - Generates comprehensive statistics and visualizations from evaluation reports

The evaluation process builds Docker containers from provided Dockerfiles and runs comprehensive tests inside them to validate the environment setup.

## Features

- **Multiple Test Types**: Supports 7 different types of tests
- **Dependency Management**: Tests can depend on other tests passing first
- **Flexible Scoring**: Each test can have custom scores (default 1) for different importance levels
- **Detailed Reporting**: JSON output with execution times and detailed results
- **Clean Resource Management**: Automatically cleans up Docker images after evaluation

## Test Categories

Each test is assigned one of three categories that group tests by their evaluation purpose:

### 1. Structure
**"Is the project properly laid out?"**
- Verifies expected files and directories are present
- Checks project configuration files exist
- Validates documentation and build files
- Examples: `files_exist`, `dirs_exist`, `file_contains` for project layout

### 2. Configuration  
**"Did the Dockerfile properly install and configure what's needed?"**
- Verifies tools, libraries, and runtimes are available
- Checks environment variables are set correctly
- Tests basic tool functionality and versions
- Examples: `commands_exist`, `envvar_set`, library import tests, version checks

### 3. Functionality
**"Can we actually use this environment to do meaningful work?"**
- Tests complex workflows and integrations
- Executes project-specific scripts and builds
- Runs end-to-end functionality tests
- Examples: Compilation tests, script execution, performance benchmarks

These categories enable analysis of where environment setup failures occur and help identify whether issues are due to missing project structure, improper dependency configuration, or integration problems.

## Supported Test Types

1. **`commands_exist`**: Check if commands are available
2. **`envvar_set`**: Check if an environment variable is set
3. **`dirs_exist`**: Check if directories exist
4. **`files_exist`**: Check if files exist
5. **`file_contains`**: Check if a file contains specific strings
6. **`run_command`**: Run a command and check if it succeeds
7. **`output_contains`**: Run a command and check if output contains specific strings

## Test Categories

Tests are organized into three high-level categories to help analyze and visualize success patterns:

### 1. **Structure**
- **Purpose**: Verify that the expected project layout and files are present
- **Question**: "Are the required files and directories in place?"
- **Examples**: 
  - `files_exist` for configuration files (Cargo.toml, build.gradle, README.md)
  - `dirs_exist` for project directories (src/, tests/, data/)
  - `file_contains` for project-specific content validation

### 2. **Configuration** 
- **Purpose**: Validate that the Dockerfile correctly installed and configured dependencies
- **Question**: "Did the Dockerfile properly set up the environment?"
- **Examples**:
  - `commands_exist` for essential tools (gcc, python, java)
  - `envvar_set` for environment variables (JAVA_HOME, CC, CXX)
  - Package import tests and version checks
  - Library availability via pkg-config

### 3. **Functionality**
- **Purpose**: Test that the environment actually works end-to-end
- **Question**: "Can we use this environment to do meaningful work?"
- **Examples**:
  - Complex `run_command` tests that compile and execute code
  - Project-specific verification scripts and test suites
  - Integration tests and simulation runs
  - Build system execution (make, cargo build, etc.)

Each test in the rubric includes a `"category"` field to enable analysis of success rates across these different aspects of environment setup.

## Usage

```bash
python DockerfileEvaluator.py --dockerfile artifacts/example.dockerfile --repo example --output reports/example_report.json --verbose
```

## Command Line Arguments

- `--dockerfile` (required): Path to the Dockerfile to evaluate
- `--repo` (required): Repository name (used to find rubric file)
- `--rubric` (optional): Path to custom rubric JSON file (default: `rubrics/manual/<repo>.json`)
- `--output` (optional): Path to save evaluation report JSON
- `--skip-warnings` (optional): Skip user confirmation prompts for potentially destructive operations
- `--verbose` (optional): Enable detailed output

## Rubric JSON Format

The rubric file should follow this structure:

```json
```json
{
  "repo": "project_name",
  "tests": [
    {
      "id": "unique_test_id",
      "type": "test_type",
      "params": {
        "parameter": "value"
      },
      "timeout": 30,
      "score": 2,
      "category": "configuration"
    }
  ]
}
```
```

### Common Test Properties

- **`id`** (optional): Unique identifier for the test, used for dependencies
- **`type`** (required): The type of test to run
- **`params`** (required): Test-specific parameters
- **`timeout`** (optional): Maximum execution time in seconds (default: 30)
- **`score`** (optional): Points awarded for passing this test (default: 1)
- **`category`** (required): Test category - one of `"structure"`, `"configuration"`, or `"functionality"`

### Test Parameters by Type

#### `commands_exist`
```json
{
  "type": "commands_exist",
  "params": {
    "names": ["java", "javac"]
  },
  "score": 2,
  "category": "configuration"
}
```

#### `output_contains`
```json
{
  "type": "output_contains",
  "params": {
    "command": "java -version",
    "contains": ["11", "17", "21"]
  },
  "timeout": 10,
  "score": 1,
  "category": "configuration"
}
```

#### `files_exist`
```json
{
  "type": "files_exist",
  "params": {
    "paths": [
      "/path/to/file"
    ]
  },
  "category": "structure"
}
```

#### `dirs_exist`
```json
{
  "type": "dirs_exist",
  "params": {
    "paths": [
      "/path/to/directory"
    ]
  },
  "category": "structure"
}
```

#### `envvar_set`
```json
{
  "type": "envvar_set",
  "params": {
    "name": "JAVA_HOME"
  },
  "category": "configuration"
}
```

#### `file_contains`
```json
{
  "type": "file_contains",
  "params": {
    "path": "/path/to/file",
    "contains": ["text1", "text2"]
  },
  "category": "structure"
}
```

#### `run_command`
```json
{
  "type": "run_command",
  "params": {
    "command": "npm --version"
  },
  "timeout": 60,
  "category": "functionality"
}
```

## Test Dependencies

Tests can depend on other tests using the `requires` field:

```json
{
  "id": "check_java",
  "type": "commands_exist",
  "params": {"names": ["java"]},
  "category": "configuration"
},
{
  "type": "output_contains",
  "params": {
    "command": "java -version",
    "contains": ["11"]
  },
  "category": "configuration"
}
```

## Output Format

The script generates a comprehensive JSON report:

```json
{
  "repo": "project_name",
  "dockerfile": "/path/to/Dockerfile",
  "rubric": "/path/to/rubric.json",
  "build_log": {
    "command": "docker build -t eval_project:latest -f /path/to/Dockerfile /build/context",
    "dockerfile_path": "/path/to/Dockerfile",
    "build_context": "/build/context",
    "scenario": "scenario_1",
    "repo_data_exists": true,
    "build_success": true,
    "build_stdout": "...",
    "build_stderr": "...",
    "build_returncode": 0,
    "build_timeout": false,
    "error_message": null
  },
  "summary": {
    "total_tests": 5,
    "passed_tests": 4,
    "failed_tests": 1,
    "total_score": 4,
    "max_score": 5,
    "success_rate": 0.8,
    "total_execution_time": 15.3
  },
  "test_results": [
    {
      "test_id": "check_java",
      "test_type": "commands_exist",
      "passed": 1,
      "score": 1,
      "message": "All commands found: java",
      "execution_time": 0.5
    }
  ]
}
```

## Batch Evaluation

The `batch_evaluate.py` script automates the evaluation of multiple Dockerfiles for a given repository, creating organized reports for comparison across different models.

### Usage

```bash
# Evaluate all dockerfiles for a repository
python batch_evaluate.py --repo facebook_zstd

# Skip existing reports to avoid re-evaluation
python batch_evaluate.py --repo facebook_zstd --skip-existing

# Only generate repository summary from existing reports
python batch_evaluate.py --repo facebook_zstd --summary-only

# Use custom directories
python batch_evaluate.py --repo facebook_zstd --baseline-dir ./ENVGYM-baseline --reports-by-model-dir ./my-reports
```

### Command Line Arguments

- `--repo` (required): Repository name to evaluate
- `--baseline-dir` (optional): Path to ENVGYM-baseline directory (default: "ENVGYM-baseline")
- `--reports-by-model-dir` (optional): Directory for individual model reports (default: "reports-by-model")
- `--reports-by-repo-dir` (optional): Directory for repository summary reports (default: "reports-by-repo")
- `--skip-existing` (optional): Skip evaluation if report already exists
- `--summary-only` (optional): Only create repo summary, skip individual evaluations
- `--skip-warnings` (optional): Skip user confirmation prompts for potentially destructive operations
- `--verbose` (optional): Enable verbose output

### Output Structure

The batch evaluator creates two types of reports:

#### 1. Individual Model Reports (`reports-by-model/`)
Mirrors the ENVGYM-baseline directory structure:
```
reports-by-model/
├── claude/
│   └── claude35haiku/
│       └── facebook_zstd/
│           └── evaluation_report.json
├── codex/
│   └── gpt4.1/
│       └── facebook_zstd/
│           └── evaluation_report.json
└── ours/
    └── claude/
        └── 35haiku/
            └── facebook_zstd/
                └── evaluation_report.json
```

#### 2. Repository Summary Reports (`reports-by-repo/`)
Comparative analysis across all models for a repository:
```
reports-by-repo/
├── facebook_zstd_summary.json       # Detailed JSON comparison
└── facebook_zstd_comparison.txt     # Human-readable table
```


## Statistics Generation

The `generate_stats.py` script analyzes evaluation reports and creates comprehensive visualizations comparing model performance across repositories and test categories.

### Usage

```bash
# Generate statistics for multiple repositories
python generate_stats.py --repos Baleen BurntSushi_ripgrep Fairify

# Use custom directories
python generate_stats.py --repos facebook_zstd --reports-dir ./reports-by-repo --output-dir ./custom-stats

# Enable verbose output
python generate_stats.py --repos Baleen Fairify --verbose
```

### Command Line Arguments

- `--repos` (required): List of repository names to analyze
- `--reports-dir` (optional): Directory containing repository reports (default: "reports-by-repo")
- `--output-dir` (optional): Output directory for statistics (default: "overview-stats")
- `--verbose` (optional): Enable verbose output

### Generated Visualizations

The script generates the following visualizations and reports:

#### Overall Analysis (`overview-stats/`)
- **`model_average_scores.png`**: Bar chart showing average percentage scores for each model
- **`combined_error_distributions.png`**: Combined pie charts showing error distribution across all models
- **`summary_report.json`**: Comprehensive JSON report with rankings and detailed statistics

#### Per-Model Analysis (`overview-stats/[model_name]/`)
- **`category_performance.png`**: Bar chart showing performance in each category (structure, configuration, functionality)
- **`comprehensive_performance.png`**: Detailed bar chart with performance across all repositories and categories
- **`error_distribution.png`**: Ring pie chart showing error composition by category

### Statistical Analysis Features

1. **Average Percentage Scores**: Calculates obtained score over maximum possible score, averaged across all specified repositories

2. **Category-Based Analysis**: Groups test results into three categories:
   - **Structure**: Project layout and file organization
   - **Configuration**: Environment setup and dependencies
   - **Functionality**: End-to-end workflow execution

3. **Cross-Repository Comparison**: Analyzes performance patterns across different types of projects

4. **Error Distribution Analysis**: Identifies which categories contribute most to evaluation failures

5. **Model Rankings**: Ranks models by overall performance and category-specific performance

## Requirements

- Python 3.7+
- Docker installed and accessible via command line
- Docker daemon running

For statistics generation (`generate_stats.py`):
- matplotlib>=3.5.0
- numpy>=1.21.0
- pandas>=1.3.0

Install visualization dependencies:
```bash
pip install -r requirements.txt
```

## Example

See `rubrics/manual/example.json` for a sample rubric file and `artifacts/example.dockerfile` for a sample Dockerfile.

### Quick Start

1. Create a rubric file for your repository in `rubrics/manual/<repo_name>.json`
2. Place your source code in `data/<repo_name>/`
3. Run the evaluator:
   ```bash
   python DockerfileEvaluator.py --dockerfile artifacts/example.dockerfile --repo example --output reports/example_report.json --verbose
   ```
4. For batch evaluation:
   ```bash
   python batch_evaluate.py --repo example --verbose
   ```

## Error Handling

- **Build Failures**: If Docker build fails, no tests are run
- **Build Timeout**: Docker builds timeout after 60 minutes (3600 seconds)
- **Command Timeout**: Individual test commands have configurable timeouts (default: 30 seconds)
- **Dependency Resolution**: Tests with unresolvable dependencies are marked as failed
- **Resource Cleanup**: Docker images and containers are always cleaned up, even on failure

## Exit Codes

- `0`: All tests passed
- `1`: Some tests failed or evaluation error
- `130`: Interrupted by user (Ctrl+C)
