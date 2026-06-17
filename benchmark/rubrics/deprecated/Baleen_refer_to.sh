#!/bin/bash
# Baleen Environment Benchmark Test
# Tests if the environment is properly set up for the Baleen ML cache simulator project
# Don't exit on error - continue testing even if some tests fail
# set -e  # Exit on any error
trap 'echo -e "\n\033[0;31m[ERROR] Script interrupted by user\033[0m"; exit 1' INT TERM

# Function to ensure clean exit
cleanup() {
    echo -e "\n\033[0;34m[INFO] Cleaning up...\033[0m"
    # Kill any background processes
    jobs -p | xargs -r kill
    exit 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Function to write results to JSON file
write_results_to_json() {
    local json_file="envgym/envbench.json"
    cat > "$json_file" << EOF
{
    "PASS": $PASS_COUNT,
    "FAIL": $FAIL_COUNT,
    "WARN": $WARN_COUNT
}
EOF
    echo -e "${BLUE}[INFO]${NC} Results written to $json_file"
}

# Check if envgym.dockerfile exists
if [ ! -f "envgym/envgym.dockerfile" ]; then
    echo -e "${RED}[CRITICAL ERROR]${NC} envgym/envgym.dockerfile does not exist"
    echo -e "${RED}[RESULT]${NC} Benchmark score: 0 (Dockerfile missing)"
    # Write 0 0 0 to JSON
    PASS_COUNT=0
    FAIL_COUNT=0
    WARN_COUNT=0
    write_results_to_json
    exit 1
fi

# Function to print status with color
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ((PASS_COUNT++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ((FAIL_COUNT++))
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ((WARN_COUNT++))
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        *)
            echo "[$status] $message"
            ;;
    esac
}

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        print_status "PASS" "$name is installed"
        return 0
    else
        print_status "FAIL" "$name is not installed"
        return 1
    fi
}

# Function to check Python version
check_python_version() {
    local python_version=$(python3 --version 2>&1)
    print_status "INFO" "Python version: $python_version"
    
    # Extract version number
    local version=$(python3 --version | sed 's/Python //')
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -eq 3 ] && [ "$minor" -ge 11 ]; then
        print_status "PASS" "Python version >= 3.11 (found $version)"
    else
        print_status "FAIL" "Python version < 3.11 (found $version)"
    fi
}

# Function to check pip version
check_pip_version() {
    local pip_version=$(pip3 --version 2>&1)
    print_status "INFO" "pip version: $pip_version"
    
    # Extract version number
    local version=$(pip3 --version | sed 's/pip //' | sed 's/ .*//')
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -ge 20 ]; then
        print_status "PASS" "pip version >= 20.x (found $version)"
    else
        print_status "FAIL" "pip version < 20.x (found $version)"
    fi
}

# Function to check conda/mamba
check_conda() {
    if command -v conda &> /dev/null; then
        local conda_version=$(conda --version 2>&1)
        print_status "INFO" "conda version: $conda_version"
        print_status "PASS" "conda is available"
        return 0
    elif command -v mamba &> /dev/null; then
        local mamba_version=$(mamba --version 2>&1)
        print_status "INFO" "mamba version: $mamba_version"
        print_status "PASS" "mamba is available"
        return 0
    elif command -v micromamba &> /dev/null; then
        local micromamba_version=$(micromamba --version 2>&1)
        print_status "INFO" "micromamba version: $micromamba_version"
        print_status "PASS" "micromamba is available"
        return 0
    else
        print_status "FAIL" "No conda/mamba/micromamba found"
        return 1
    fi
}

# Check if we're running inside Docker container
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "Running inside Docker container - proceeding with environment test..."
else
    echo "Not running in Docker container - building and running Docker test..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker is not installed or not in PATH"
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "envgym/envgym.dockerfile" ]; then
        echo "ERROR: envgym.dockerfile not found. Please run this script from the Baleen project root directory."
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo "Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t baleen-env-test .; then
        echo -e "${RED}[CRITICAL ERROR]${NC} Docker build failed"
        echo -e "${RED}[RESULT]${NC} Benchmark score: 0 (Docker build failed)"
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Run this script inside Docker container
    echo "Running environment test in Docker container..."
    docker run --rm -v "$(pwd):/home/cc/EnvGym/data/Baleen" baleen-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        ./envgym/envbench.sh
    "
    exit 0
fi

echo "=========================================="
echo "Baleen Environment Benchmark Test"
echo "=========================================="
echo ""

echo "1. Checking System Dependencies..."
echo "--------------------------------"
# Check system commands
check_command "python3" "Python 3"
check_command "pip3" "pip3"
check_command "git" "Git"
check_command "curl" "cURL"
check_command "wget" "wget"
check_command "bash" "Bash"
check_command "tar" "tar"
check_command "gzip" "gzip"
check_command "bzip2" "bzip2"
check_command "build-essential" "build-essential"

echo ""
echo "2. Checking Python Environment..."
echo "--------------------------------"
check_python_version
check_pip_version

# Check Python packages
echo ""
echo "3. Checking Python Packages..."
echo "------------------------------"
print_status "INFO" "Checking Python packages..."

# Check if JupyterLab is installed
if python3 -c "import jupyterlab" 2>/dev/null; then
    print_status "PASS" "JupyterLab is installed"
else
    print_status "FAIL" "JupyterLab is not installed"
fi

# Check if numpy is installed
if python3 -c "import numpy" 2>/dev/null; then
    print_status "PASS" "numpy is installed"
else
    print_status "FAIL" "numpy is not installed"
fi

# Check if pandas is installed
if python3 -c "import pandas" 2>/dev/null; then
    print_status "PASS" "pandas is installed"
else
    print_status "FAIL" "pandas is not installed"
fi

# Check if matplotlib is installed
if python3 -c "import matplotlib" 2>/dev/null; then
    print_status "PASS" "matplotlib is installed"
else
    print_status "FAIL" "matplotlib is not installed"
fi

# Check if scikit-learn is installed
if python3 -c "import sklearn" 2>/dev/null; then
    print_status "PASS" "scikit-learn is installed"
else
    print_status "FAIL" "scikit-learn is not installed"
fi

# Check if torch is installed
if python3 -c "import torch" 2>/dev/null; then
    print_status "PASS" "PyTorch is installed"
else
    print_status "WARN" "PyTorch is not installed (optional for some features)"
fi

# Check if tensorflow is installed
if python3 -c "import tensorflow" 2>/dev/null; then
    print_status "PASS" "TensorFlow is installed"
else
    print_status "WARN" "TensorFlow is not installed (optional for some features)"
fi

echo ""
echo "4. Checking Conda/Mamba Environment..."
echo "-------------------------------------"
check_conda

echo ""
echo "5. Checking Project Structure..."
echo "-------------------------------"
# Check if we're in the right directory
if [ -f "README.md" ]; then
    print_status "PASS" "README.md found"
else
    print_status "FAIL" "README.md not found"
    exit 1
fi

# Check if we're in the Baleen project
if grep -q "Baleen" README.md 2>/dev/null; then
    print_status "PASS" "Baleen project detected"
else
    print_status "FAIL" "Not a Baleen project"
fi

# Check project structure
print_status "INFO" "Checking project structure..."

if [ -d "BCacheSim" ]; then
    print_status "PASS" "BCacheSim directory exists"
else
    print_status "FAIL" "BCacheSim directory missing"
fi

if [ -d "data" ]; then
    print_status "PASS" "data directory exists"
else
    print_status "FAIL" "data directory missing"
fi

if [ -d "notebooks" ]; then
    print_status "PASS" "notebooks directory exists"
else
    print_status "FAIL" "notebooks directory missing"
fi

if [ -d "runs" ]; then
    print_status "PASS" "runs directory exists"
else
    print_status "FAIL" "runs directory missing"
fi

if [ -d "chameleon" ]; then
    print_status "PASS" "chameleon directory exists"
else
    print_status "FAIL" "chameleon directory missing"
fi

echo ""
echo "6. Checking BCacheSim Structure..."
echo "----------------------------------"
# Check BCacheSim structure
if [ -d "BCacheSim" ]; then
    if [ -d "BCacheSim/install" ]; then
        print_status "PASS" "BCacheSim/install directory exists"
    else
        print_status "FAIL" "BCacheSim/install directory missing"
    fi
    
    if [ -d "BCacheSim/cachesim" ]; then
        print_status "PASS" "BCacheSim/cachesim directory exists"
    else
        print_status "FAIL" "BCacheSim/cachesim directory missing"
    fi
    
    if [ -d "BCacheSim/episodic_analysis" ]; then
        print_status "PASS" "BCacheSim/episodic_analysis directory exists"
    else
        print_status "FAIL" "BCacheSim/episodic_analysis directory missing"
    fi
    
    if [ -f "BCacheSim/run_py.sh" ]; then
        print_status "PASS" "BCacheSim/run_py.sh exists"
        if [ -x "BCacheSim/run_py.sh" ]; then
            print_status "PASS" "BCacheSim/run_py.sh is executable"
        else
            print_status "FAIL" "BCacheSim/run_py.sh is not executable"
        fi
    else
        print_status "FAIL" "BCacheSim/run_py.sh missing"
    fi
fi

echo ""
echo "7. Checking Data Directory..."
echo "-----------------------------"
# Check data directory
if [ -d "data" ]; then
    if [ -f "data/get-tectonic.sh" ]; then
        print_status "PASS" "data/get-tectonic.sh exists"
        if [ -x "data/get-tectonic.sh" ]; then
            print_status "PASS" "data/get-tectonic.sh is executable"
        else
            print_status "FAIL" "data/get-tectonic.sh is not executable"
        fi
    else
        print_status "FAIL" "data/get-tectonic.sh missing"
    fi
    
    if [ -f "data/clean.sh" ]; then
        print_status "PASS" "data/clean.sh exists"
    else
        print_status "FAIL" "data/clean.sh missing"
    fi
fi

echo ""
echo "8. Checking Notebooks Structure..."
echo "----------------------------------"
# Check notebooks structure
if [ -d "notebooks" ]; then
    if [ -d "notebooks/example" ]; then
        print_status "PASS" "notebooks/example directory exists"
        
        # Check for example notebook
        if [ -f "notebooks/example/example.ipynb" ]; then
            print_status "PASS" "notebooks/example/example.ipynb exists"
        else
            print_status "FAIL" "notebooks/example/example.ipynb missing"
        fi
    else
        print_status "FAIL" "notebooks/example directory missing"
    fi
    
    if [ -d "notebooks/paper-figs" ]; then
        print_status "PASS" "notebooks/paper-figs directory exists"
    else
        print_status "FAIL" "notebooks/paper-figs directory missing"
    fi
    
    if [ -d "notebooks/reproduce" ]; then
        print_status "PASS" "notebooks/reproduce directory exists"
    else
        print_status "FAIL" "notebooks/reproduce directory missing"
    fi
fi

echo ""
echo "9. Checking Runs Configuration..."
echo "---------------------------------"
# Check runs configuration
if [ -d "runs" ]; then
    if [ -d "runs/example" ]; then
        print_status "PASS" "runs/example directory exists"
        
        # Check for example configurations
        if [ -d "runs/example/rejectx" ]; then
            print_status "PASS" "runs/example/rejectx directory exists"
            if [ -f "runs/example/rejectx/config.json" ]; then
                print_status "PASS" "runs/example/rejectx/config.json exists"
            else
                print_status "FAIL" "runs/example/rejectx/config.json missing"
            fi
        else
            print_status "FAIL" "runs/example/rejectx directory missing"
        fi
        
        if [ -d "runs/example/baleen" ]; then
            print_status "PASS" "runs/example/baleen directory exists"
        else
            print_status "FAIL" "runs/example/baleen directory missing"
        fi
    else
        print_status "FAIL" "runs/example directory missing"
    fi
fi

echo ""
echo "10. Checking Scripts..."
echo "----------------------"
# Check scripts
if [ -f "getting-started.sh" ]; then
    print_status "PASS" "getting-started.sh exists"
    if [ -x "getting-started.sh" ]; then
        print_status "PASS" "getting-started.sh is executable"
    else
        print_status "FAIL" "getting-started.sh is not executable"
    fi
else
    print_status "FAIL" "getting-started.sh missing"
fi

echo ""
echo "11. Testing Python Module Imports..."
echo "-----------------------------------"
# Test Python module imports
print_status "INFO" "Testing Python module imports..."

# Test basic Python functionality
if python3 -c "print('Python is working')" 2>/dev/null; then
    print_status "PASS" "Python basic functionality works"
else
    print_status "FAIL" "Python basic functionality failed"
fi

# Test BCacheSim imports (if available)
if [ -d "BCacheSim" ]; then
    if python3 -c "import sys; sys.path.append('BCacheSim'); import cachesim" 2>/dev/null; then
        print_status "PASS" "BCacheSim.cachesim module can be imported"
    else
        print_status "WARN" "BCacheSim.cachesim module cannot be imported (may need setup)"
    fi
    
    if python3 -c "import sys; sys.path.append('BCacheSim'); import episodic_analysis" 2>/dev/null; then
        print_status "PASS" "BCacheSim.episodic_analysis module can be imported"
    else
        print_status "WARN" "BCacheSim.episodic_analysis module cannot be imported (may need setup)"
    fi
fi

echo ""
echo "12. Testing JupyterLab..."
echo "-------------------------"
# Test JupyterLab
if command -v jupyter &> /dev/null; then
    jupyter_version=$(jupyter --version 2>&1)
    print_status "INFO" "Jupyter version: $jupyter_version"
    print_status "PASS" "Jupyter is available"
else
    print_status "FAIL" "Jupyter is not available"
fi

if command -v jupyter-lab &> /dev/null; then
    print_status "PASS" "JupyterLab is available"
else
    print_status "FAIL" "JupyterLab is not available"
fi

echo ""
echo "13. Testing Data Download Script..."
echo "-----------------------------------"
# Test data download script
if [ -f "data/get-tectonic.sh" ] && [ -x "data/get-tectonic.sh" ]; then
    print_status "INFO" "Testing data download script syntax..."
    if bash -n data/get-tectonic.sh 2>/dev/null; then
        print_status "PASS" "data/get-tectonic.sh syntax is valid"
    else
        print_status "FAIL" "data/get-tectonic.sh syntax is invalid"
    fi
fi

echo ""
echo "14. Testing BCacheSim Script..."
echo "-------------------------------"
# Test BCacheSim script
if [ -f "BCacheSim/run_py.sh" ] && [ -x "BCacheSim/run_py.sh" ]; then
    print_status "INFO" "Testing BCacheSim script syntax..."
    if bash -n BCacheSim/run_py.sh 2>/dev/null; then
        print_status "PASS" "BCacheSim/run_py.sh syntax is valid"
    else
        print_status "FAIL" "BCacheSim/run_py.sh syntax is invalid"
    fi
fi

echo ""
echo "15. Testing Getting Started Script..."
echo "-------------------------------------"
# Test getting started script
if [ -f "getting-started.sh" ] && [ -x "getting-started.sh" ]; then
    print_status "INFO" "Testing getting-started.sh syntax..."
    if bash -n getting-started.sh 2>/dev/null; then
        print_status "PASS" "getting-started.sh syntax is valid"
    else
        print_status "FAIL" "getting-started.sh syntax is invalid"
    fi
fi

echo ""
echo "16. Testing Required Directories..."
echo "-----------------------------------"
# Test required directories
print_status "INFO" "Checking required directories..."

# Check if required directories exist (as mentioned in Dockerfile)
if [ -d "runs" ]; then
    print_status "PASS" "runs directory exists"
else
    print_status "FAIL" "runs directory missing"
fi

if [ -d "tmp" ]; then
    print_status "PASS" "tmp directory exists"
else
    print_status "WARN" "tmp directory missing (will be created during runtime)"
fi

if [ -d "notebooks/figs" ]; then
    print_status "PASS" "notebooks/figs directory exists"
else
    print_status "WARN" "notebooks/figs directory missing (will be created during runtime)"
fi

if [ -d "data" ]; then
    print_status "PASS" "data directory exists"
else
    print_status "FAIL" "data directory missing"
fi

echo ""
echo "17. Testing Locale Configuration..."
echo "-----------------------------------"
# Test locale configuration
if [ "$LANG" = "en_US.UTF-8" ]; then
    print_status "PASS" "LANG is set to en_US.UTF-8"
else
    print_status "WARN" "LANG is not set to en_US.UTF-8 (current: $LANG)"
fi

if [ "$LC_ALL" = "en_US.UTF-8" ]; then
    print_status "PASS" "LC_ALL is set to en_US.UTF-8"
else
    print_status "WARN" "LC_ALL is not set to en_US.UTF-8 (current: $LC_ALL)"
fi

echo ""
echo "18. Testing Timezone Configuration..."
echo "-------------------------------------"
# Test timezone configuration
if [ "$TZ" = "UTC" ]; then
    print_status "PASS" "TZ is set to UTC"
else
    print_status "WARN" "TZ is not set to UTC (current: $TZ)"
fi

echo ""
echo "19. Testing Git Configuration..."
echo "--------------------------------"
# Test Git configuration
if git --version >/dev/null 2>&1; then
    print_status "PASS" "Git is properly configured"
else
    print_status "FAIL" "Git is not properly configured"
fi

# Check if this is a Git repository
if [ -d ".git" ]; then
    print_status "PASS" "This is a Git repository"
else
    print_status "WARN" "This is not a Git repository"
fi

# Check for submodules
if [ -f ".gitmodules" ]; then
    print_status "PASS" "Git submodules configuration exists"
else
    print_status "WARN" "Git submodules configuration missing"
fi

echo ""
echo "20. Testing Network Connectivity..."
echo "-----------------------------------"
# Test network connectivity (for data downloads)
if curl -s --head https://ftp.pdl.cmu.edu >/dev/null 2>&1; then
    print_status "PASS" "Network connectivity to CMU FTP server is available"
else
    print_status "WARN" "Network connectivity to CMU FTP server is not available"
fi

if curl -s --head https://github.com >/dev/null 2>&1; then
    print_status "PASS" "Network connectivity to GitHub is available"
else
    print_status "WARN" "Network connectivity to GitHub is not available"
fi

echo ""
echo "=========================================="
echo "Environment Benchmark Test Complete"
echo "=========================================="

# Summary
echo ""
echo "Summary:"
echo "--------"
echo "This script has tested:"
echo "- System dependencies (Python 3.11+, pip, Git, curl, wget, build tools)"
echo "- Python environment and packages (JupyterLab, numpy, pandas, matplotlib, scikit-learn)"
echo "- Conda/Mamba environment management"
echo "- Project structure and files"
echo "- BCacheSim simulator components"
echo "- Data download scripts"
echo "- Jupyter notebooks structure"
echo "- Configuration files"
echo "- Script syntax validation"
echo "- Locale and timezone configuration"
echo "- Git repository setup"
echo "- Network connectivity"
echo ""

# Save final counts before any additional print_status calls
FINAL_PASS_COUNT=$PASS_COUNT
FINAL_FAIL_COUNT=$FAIL_COUNT
FINAL_WARN_COUNT=$WARN_COUNT

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo -e "${GREEN}PASS: $FINAL_PASS_COUNT${NC}"
echo -e "${RED}FAIL: $FINAL_FAIL_COUNT${NC}"
echo -e "${YELLOW}WARN: $FINAL_WARN_COUNT${NC}"

# Write results to JSON using the final counts
PASS_COUNT=$FINAL_PASS_COUNT
FAIL_COUNT=$FINAL_FAIL_COUNT
WARN_COUNT=$FINAL_WARN_COUNT
write_results_to_json

if [ $FINAL_FAIL_COUNT -eq 0 ]; then
    print_status "INFO" "All tests passed! Your Baleen environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your Baleen environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi

print_status "INFO" "You can now run Baleen experiments."
print_status "INFO" "Example: ./getting-started.sh"
print_status "INFO" "Or follow the README.md instructions for detailed setup."

echo ""
print_status "INFO" "For more information, see README.md"
print_status "INFO" "For video walkthrough, see: https://www.tiny.cc/BaleenArtifactYT"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/EnvGym/data/Baleen baleen-env-test /bin/bash" 