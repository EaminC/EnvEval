#!/bin/bash

# Fairify Environment Benchmark Test Script
# This script tests the environment setup for Fairify neural network fairness verification

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
    # Ensure the directory exists and has proper permissions
    mkdir -p "$(dirname "$json_file")"
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

# Function to print status with colors
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
    esac
}

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=${2:-$1}
    if command -v "$cmd" &> /dev/null; then
        print_status "PASS" "$name is available"
        return 0
    else
        print_status "FAIL" "$name is not available"
        return 1
    fi
}

# Function to check Python version
check_python_version() {
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1)
        local python_major=$(echo "${python_version:-}" | cut -d' ' -f2 | cut -d'.' -f1)
        local python_minor=$(echo "${python_version:-}" | cut -d' ' -f2 | cut -d'.' -f2)
        if [ -n "${python_major:-}" ] && [ "${python_major:-}" -eq 3 ] && [ -n "${python_minor:-}" ] && [ "${python_minor:-}" -ge 7 ]; then
            print_status "PASS" "Python version >= 3.7 (${python_version:-})"
        else
            print_status "WARN" "Python version should be >= 3.7 (${python_version:-})"
        fi
    else
        print_status "FAIL" "Python3 not found"
    fi
}

# Function to check conda version
check_conda_version() {
    if command -v conda &> /dev/null; then
        local conda_version=$(conda --version 2>&1)
        print_status "PASS" "Conda is available: $conda_version"
    else
        print_status "WARN" "Conda is not available"
    fi
}

# Check if we're running inside Docker container
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo -e "${BLUE}[INFO]${NC} Running inside Docker container - proceeding with environment test..."
else
    echo -e "${BLUE}[INFO]${NC} Not running in Docker container - building and running Docker test..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} Docker is not installed or not in PATH"
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "envgym/envgym.dockerfile" ]; then
        echo -e "${RED}[ERROR]${NC} envgym.dockerfile not found. Please run this script from the Fairify project root directory."
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo -e "${BLUE}[INFO]${NC} Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t fairify-env-test .; then
        echo -e "${RED}[CRITICAL ERROR]${NC} Docker build failed"
        echo -e "${RED}[RESULT]${NC} Benchmark score: 0 (Docker build failed)"
        
        # Analyze Dockerfile if build failed
        echo ""
        echo -e "${BLUE}Analyzing Dockerfile...${NC}"
        echo -e "${BLUE}----------------------${NC}"
        
        # Check Dockerfile structure
        if grep -q "FROM" envgym/envgym.dockerfile; then
            print_status "PASS" "FROM instruction found"
        else
            print_status "FAIL" "FROM instruction not found"
        fi
        
        if grep -q "ubuntu:22.04" envgym/envgym.dockerfile; then
            print_status "PASS" "Ubuntu 22.04 specified"
        else
            print_status "WARN" "Ubuntu 22.04 not specified"
        fi
        
        if grep -q "WORKDIR" envgym/envgym.dockerfile; then
            print_status "PASS" "WORKDIR set"
        else
            print_status "WARN" "WORKDIR not set"
        fi
        
        if grep -q "miniconda" envgym/envgym.dockerfile; then
            print_status "PASS" "Miniconda found"
        else
            print_status "FAIL" "Miniconda not found"
        fi
        
        if grep -q "python=3.7" envgym/envgym.dockerfile; then
            print_status "PASS" "Python 3.7 specified"
        else
            print_status "WARN" "Python 3.7 not specified"
        fi
        
        if grep -q "conda" envgym/envgym.dockerfile; then
            print_status "PASS" "Conda environment management found"
        else
            print_status "FAIL" "Conda environment management not found"
        fi
        
        if grep -q "requirements.txt" envgym/envgym.dockerfile; then
            print_status "PASS" "requirements.txt found"
        else
            print_status "FAIL" "requirements.txt not found"
        fi
        
        if grep -q "pip install" envgym/envgym.dockerfile; then
            print_status "PASS" "pip install found"
        else
            print_status "FAIL" "pip install not found"
        fi
        
        if grep -q "COPY" envgym/envgym.dockerfile; then
            print_status "PASS" "COPY instruction found"
        else
            print_status "WARN" "COPY instruction not found"
        fi
        
        if grep -q "ENTRYPOINT" envgym/envgym.dockerfile; then
            print_status "PASS" "ENTRYPOINT found"
        else
            print_status "WARN" "ENTRYPOINT not found"
        fi
        
        if grep -q "git" envgym/envgym.dockerfile; then
            print_status "PASS" "git found"
        else
            print_status "WARN" "git not found"
        fi
        
        if grep -q "bash" envgym/envgym.dockerfile; then
            print_status "PASS" "bash found"
        else
            print_status "WARN" "bash not found"
        fi
        
        echo ""
        total_dockerfile_checks=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
        if [ $total_dockerfile_checks -gt 0 ]; then
            dockerfile_score=$((PASS_COUNT * 100 / total_dockerfile_checks))
        else
            dockerfile_score=0
        fi
        print_status "INFO" "Dockerfile Environment Score: $dockerfile_score% ($PASS_COUNT/$total_dockerfile_checks checks passed)"
        print_status "INFO" "PASS: $PASS_COUNT, FAIL: $((FAIL_COUNT)), WARN: $((WARN_COUNT))"
        if [ $FAIL_COUNT -eq 0 ]; then
            print_status "INFO" "Dockerfile结构良好，建议检查依赖版本和构建产物。"
        else
            print_status "WARN" "Dockerfile存在一些问题，建议修复后重新构建。"
        fi
        
        # Write results to JSON
        write_results_to_json
        exit 1
    fi
    
    # Run this script inside Docker container
    echo -e "${BLUE}[INFO]${NC} Running environment test in Docker container..."
    docker run --rm -v "$(pwd):/home/cc/EnvGym/data/Fairify" --entrypoint="" fairify-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        source /opt/conda/etc/profile.d/conda.sh
        conda activate fairify
        cd /home/cc/EnvGym/data/Fairify
        bash envgym/envbench.sh
    "
    exit 0
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Fairify Environment Benchmark Test${NC}"
echo -e "${BLUE}==========================================${NC}"

echo -e "${BLUE}1. Checking System Dependencies...${NC}"
echo -e "${BLUE}--------------------------------${NC}"
check_command "python3" "Python3"
check_command "pip3" "pip3"
check_command "git" "Git"
check_command "bash" "Bash"
check_command "curl" "curl"
check_command "wget" "wget"

# Python version check
check_python_version

# Conda version check
check_conda_version

echo ""
echo -e "${BLUE}2. Checking Project Structure...${NC}"
echo -e "${BLUE}-------------------------------${NC}"
[ -f "requirements.txt" ] && print_status "PASS" "requirements.txt exists" || print_status "FAIL" "requirements.txt missing"
[ -f "README.md" ] && print_status "PASS" "README.md exists" || print_status "FAIL" "README.md missing"
[ -f "INSTALL.md" ] && print_status "PASS" "INSTALL.md exists" || print_status "FAIL" "INSTALL.md missing"
[ -f "LICENSE" ] && print_status "PASS" "LICENSE exists" || print_status "FAIL" "LICENSE missing"
[ -f "STATUS.md" ] && print_status "PASS" "STATUS.md exists" || print_status "FAIL" "STATUS.md missing"

# Check main directories
[ -d "src" ] && print_status "PASS" "src directory exists" || print_status "FAIL" "src directory missing"
[ -d "models" ] && print_status "PASS" "models directory exists" || print_status "FAIL" "models directory missing"
[ -d "data" ] && print_status "PASS" "data directory exists" || print_status "FAIL" "data directory missing"
[ -d "utils" ] && print_status "PASS" "utils directory exists" || print_status "FAIL" "utils directory missing"
[ -d "stress" ] && print_status "PASS" "stress directory exists" || print_status "FAIL" "stress directory missing"
[ -d "relaxed" ] && print_status "PASS" "relaxed directory exists" || print_status "FAIL" "relaxed directory missing"
[ -d "targeted" ] && print_status "PASS" "targeted directory exists" || print_status "FAIL" "targeted directory missing"
[ -d "targeted2" ] && print_status "PASS" "targeted2 directory exists" || print_status "FAIL" "targeted2 directory missing"

# Check src subdirectories
[ -d "src/GC" ] && print_status "PASS" "src/GC directory exists" || print_status "FAIL" "src/GC directory missing"
[ -d "src/AC" ] && print_status "PASS" "src/AC directory exists" || print_status "FAIL" "src/AC directory missing"
[ -d "src/BM" ] && print_status "PASS" "src/BM directory exists" || print_status "FAIL" "src/BM directory missing"

# Check model directories
[ -d "models/german" ] && print_status "PASS" "models/german directory exists" || print_status "FAIL" "models/german directory missing"
[ -d "models/adult" ] && print_status "PASS" "models/adult directory exists" || print_status "FAIL" "models/adult directory missing"
[ -d "models/bank" ] && print_status "PASS" "models/bank directory exists" || print_status "FAIL" "models/bank directory missing"

# Check data directories
[ -d "data/german" ] && print_status "PASS" "data/german directory exists" || print_status "FAIL" "data/german directory missing"
[ -d "data/adult" ] && print_status "PASS" "data/adult directory exists" || print_status "FAIL" "data/adult directory missing"
[ -d "data/bank" ] && print_status "PASS" "data/bank directory exists" || print_status "FAIL" "data/bank directory missing"

echo ""
echo -e "${BLUE}3. Checking Environment Variables...${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
# Check Python environment
if [ -n "${PYTHONPATH:-}" ]; then
    print_status "PASS" "PYTHONPATH is set: $PYTHONPATH"
else
    print_status "WARN" "PYTHONPATH is not set"
fi

if [ -n "${VIRTUAL_ENV:-}" ]; then
    print_status "PASS" "VIRTUAL_ENV is set: $VIRTUAL_ENV"
else
    print_status "WARN" "VIRTUAL_ENV is not set"
fi

if [ -n "${CONDA_DEFAULT_ENV:-}" ]; then
    print_status "PASS" "CONDA_DEFAULT_ENV is set: $CONDA_DEFAULT_ENV"
else
    print_status "WARN" "CONDA_DEFAULT_ENV is not set"
fi

# Check PATH
if echo "$PATH" | grep -q "python"; then
    print_status "PASS" "Python is in PATH"
else
    print_status "WARN" "Python is not in PATH"
fi

if echo "$PATH" | grep -q "pip"; then
    print_status "PASS" "pip is in PATH"
else
    print_status "WARN" "pip is not in PATH"
fi

if echo "$PATH" | grep -q "conda"; then
    print_status "PASS" "conda is in PATH"
else
    print_status "WARN" "conda is not in PATH"
fi

echo ""
echo -e "${BLUE}4. Testing Python Environment...${NC}"
echo -e "${BLUE}-------------------------------${NC}"
# Test Python3
if command -v python3 &> /dev/null; then
    print_status "PASS" "python3 is available"
    
    # Test Python3 execution
    if timeout 30s python3 -c "print('Hello from Python3')" >/dev/null 2>&1; then
        print_status "PASS" "Python3 execution works"
    else
        print_status "WARN" "Python3 execution failed"
    fi
    
    # Test Python3 import system
    if timeout 30s python3 -c "import sys; print('Python path:', sys.path[0])" >/dev/null 2>&1; then
        print_status "PASS" "Python3 import system works"
    else
        print_status "WARN" "Python3 import system failed"
    fi
else
    print_status "FAIL" "python3 is not available"
fi

echo ""
echo -e "${BLUE}5. Testing Package Management...${NC}"
echo -e "${BLUE}-------------------------------${NC}"
# Test pip3
if command -v pip3 &> /dev/null; then
    print_status "PASS" "pip3 is available"
    
    # Test pip3 version
    if timeout 30s pip3 --version >/dev/null 2>&1; then
        print_status "PASS" "pip3 version command works"
    else
        print_status "WARN" "pip3 version command failed"
    fi
    
    # Test pip3 list
    if timeout 30s pip3 list >/dev/null 2>&1; then
        print_status "PASS" "pip3 list command works"
    else
        print_status "WARN" "pip3 list command failed"
    fi
else
    print_status "FAIL" "pip3 is not available"
fi

# Test conda
if command -v conda &> /dev/null; then
    print_status "PASS" "conda is available"
    
    # Test conda info
    if timeout 30s conda info >/dev/null 2>&1; then
        print_status "PASS" "conda info command works"
    else
        print_status "WARN" "conda info command failed"
    fi
    
    # Test conda env list
    if timeout 30s conda env list >/dev/null 2>&1; then
        print_status "PASS" "conda env list command works"
    else
        print_status "WARN" "conda env list command failed"
    fi
else
    print_status "WARN" "conda is not available"
fi

echo ""
echo -e "${BLUE}6. Testing Package Installation...${NC}"
echo -e "${BLUE}----------------------------------${NC}"
# Test package installation
if command -v pip3 &> /dev/null && [ -f "requirements.txt" ]; then
    print_status "PASS" "pip3 and requirements.txt are available"
    
    # Test pip3 install from requirements.txt
    if timeout 120s pip3 install -r requirements.txt >/dev/null 2>&1; then
        print_status "PASS" "pip3 install from requirements.txt works"
    else
        print_status "WARN" "pip3 install from requirements.txt failed"
    fi
else
    print_status "WARN" "pip3 or requirements.txt not available"
fi

echo ""
echo -e "${BLUE}7. Testing Fairify Dependencies...${NC}"
echo -e "${BLUE}----------------------------------${NC}"
# Test Z3 solver
if command -v python3 &> /dev/null; then
    if timeout 30s python3 -c "import z3; print('Z3 version:', z3.get_version_string())" >/dev/null 2>&1; then
        print_status "PASS" "Z3 solver is available"
    else
        print_status "WARN" "Z3 solver is not available"
    fi
else
    print_status "WARN" "python3 not available for Z3 test"
fi

# Test TensorFlow
if command -v python3 &> /dev/null; then
    if timeout 30s python3 -c "import tensorflow as tf; print('TensorFlow version:', tf.__version__)" >/dev/null 2>&1; then
        print_status "PASS" "TensorFlow is available"
    else
        print_status "WARN" "TensorFlow is not available"
    fi
else
    print_status "WARN" "python3 not available for TensorFlow test"
fi

# Test AIF360
if command -v python3 &> /dev/null; then
    if timeout 30s python3 -c "import aif360; print('AIF360 version:', aif360.__version__)" >/dev/null 2>&1; then
        print_status "PASS" "AIF360 is available"
    else
        print_status "WARN" "AIF360 is not available"
    fi
else
    print_status "WARN" "python3 not available for AIF360 test"
fi

echo ""
echo -e "${BLUE}8. Testing Fairify Scripts...${NC}"
echo -e "${BLUE}-----------------------------${NC}"
# Test fairify.sh script
if [ -f "src/fairify.sh" ] && [ -x "src/fairify.sh" ]; then
    print_status "PASS" "src/fairify.sh exists and is executable"
else
    print_status "WARN" "src/fairify.sh not found or not executable"
fi

# Test if scripts can be made executable
if [ -f "src/fairify.sh" ]; then
    if chmod +x src/fairify.sh 2>/dev/null; then
        print_status "PASS" "src/fairify.sh can be made executable"
    else
        print_status "WARN" "src/fairify.sh cannot be made executable"
    fi
fi

# Check for other script files
if [ -f "stress/fairify-stress.sh" ]; then
    print_status "PASS" "stress/fairify-stress.sh exists"
else
    print_status "WARN" "stress/fairify-stress.sh not found"
fi

if [ -f "relaxed/fairify-relaxed.sh" ]; then
    print_status "PASS" "relaxed/fairify-relaxed.sh exists"
else
    print_status "WARN" "relaxed/fairify-relaxed.sh not found"
fi

if [ -f "targeted/fairify-targeted.sh" ]; then
    print_status "PASS" "targeted/fairify-targeted.sh exists"
else
    print_status "WARN" "targeted/fairify-targeted.sh not found"
fi

if [ -f "targeted2/fairify-targeted.sh" ]; then
    print_status "PASS" "targeted2/fairify-targeted.sh exists"
else
    print_status "WARN" "targeted2/fairify-targeted.sh not found"
fi

echo ""
echo -e "${BLUE}9. Testing Fairify Python Modules...${NC}"
echo -e "${BLUE}------------------------------------${NC}"
# Test if verification scripts exist and can be imported
if [ -f "src/GC/Verify-GC.py" ]; then
    print_status "PASS" "src/GC/Verify-GC.py exists"
    
    # Test if it can be executed
    if command -v python3 &> /dev/null; then
        if timeout 30s python3 -c "import sys; sys.path.append('src/GC'); exec(open('src/GC/Verify-GC.py').read())" >/dev/null 2>&1; then
            print_status "PASS" "src/GC/Verify-GC.py can be executed"
        else
            print_status "WARN" "src/GC/Verify-GC.py execution failed"
        fi
    else
        print_status "WARN" "python3 not available for script execution test"
    fi
else
    print_status "FAIL" "src/GC/Verify-GC.py not found"
fi

# Check for other verification scripts
if [ -f "src/AC/Verify-AC.py" ]; then
    print_status "PASS" "src/AC/Verify-AC.py exists"
else
    print_status "WARN" "src/AC/Verify-AC.py not found"
fi

if [ -f "src/BM/Verify-BM.py" ]; then
    print_status "PASS" "src/BM/Verify-BM.py exists"
else
    print_status "WARN" "src/BM/Verify-BM.py not found"
fi

echo ""
echo -e "${BLUE}10. Testing Model and Data Files...${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
# Test if model files exist
if [ -d "models/german" ] && [ "$(ls -A models/german 2>/dev/null)" ]; then
    print_status "PASS" "models/german contains files"
else
    print_status "WARN" "models/german is empty or not accessible"
fi

if [ -d "models/adult" ] && [ "$(ls -A models/adult 2>/dev/null)" ]; then
    print_status "PASS" "models/adult contains files"
else
    print_status "WARN" "models/adult is empty or not accessible"
fi

if [ -d "models/bank" ] && [ "$(ls -A models/bank 2>/dev/null)" ]; then
    print_status "PASS" "models/bank contains files"
else
    print_status "WARN" "models/bank is empty or not accessible"
fi

# Test if data files exist
if [ -d "data/german" ] && [ "$(ls -A data/german 2>/dev/null)" ]; then
    print_status "PASS" "data/german contains files"
else
    print_status "WARN" "data/german is empty or not accessible"
fi

if [ -d "data/adult" ] && [ "$(ls -A data/adult 2>/dev/null)" ]; then
    print_status "PASS" "data/adult contains files"
else
    print_status "WARN" "data/adult is empty or not accessible"
fi

if [ -d "data/bank" ] && [ "$(ls -A data/bank 2>/dev/null)" ]; then
    print_status "PASS" "data/bank contains files"
else
    print_status "WARN" "data/bank is empty or not accessible"
fi

echo ""
echo -e "${BLUE}11. Testing Virtual Environment...${NC}"
echo -e "${BLUE}----------------------------------${NC}"
# Test virtual environment creation
if command -v python3 &> /dev/null; then
    print_status "PASS" "python3 is available for virtual environment testing"
    
    # Test venv module
    if timeout 30s python3 -c "import venv; print('venv module available')" >/dev/null 2>&1; then
        print_status "PASS" "venv module is available"
    else
        print_status "WARN" "venv module is not available"
    fi
else
    print_status "WARN" "python3 not available for virtual environment testing"
fi

echo ""
echo -e "${BLUE}12. Testing Documentation...${NC}"
echo -e "${BLUE}----------------------------${NC}"
# Test if documentation files are readable
if [ -r "README.md" ]; then
    print_status "PASS" "README.md is readable"
else
    print_status "WARN" "README.md is not readable"
fi

if [ -r "INSTALL.md" ]; then
    print_status "PASS" "INSTALL.md is readable"
else
    print_status "WARN" "INSTALL.md is not readable"
fi

if [ -r "STATUS.md" ]; then
    print_status "PASS" "STATUS.md is readable"
else
    print_status "WARN" "STATUS.md is not readable"
fi

if [ -r "LICENSE" ]; then
    print_status "PASS" "LICENSE is readable"
else
    print_status "WARN" "LICENSE is not readable"
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Environment Benchmark Test Complete${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "${BLUE}--------${NC}"
echo -e "${BLUE}This script has tested:${NC}"
echo "- System dependencies (Python3 3.7+, pip3, conda, git, bash)"
echo "- Project structure (src/, models/, data/, utils/, stress/, relaxed/, targeted/)"
echo "- Environment variables (PYTHONPATH, VIRTUAL_ENV, CONDA_DEFAULT_ENV, PATH)"
echo "- Python environment (python3, import system)"
echo "- Package management (pip3, conda)"
echo "- Package installation (requirements.txt)"
echo "- Fairify dependencies (Z3 solver, TensorFlow, AIF360)"
echo "- Fairify scripts (fairify.sh, verification scripts)"
echo "- Fairify Python modules (Verify-GC.py, Verify-AC.py, Verify-BM.py)"
echo "- Model and data files (german, adult, bank datasets)"
echo "- Virtual environment (venv module)"
echo "- Documentation (README.md, INSTALL.md, STATUS.md, LICENSE)"
echo "- Dockerfile structure (if Docker build failed)"

# Save final counts before any additional print_status calls
FINAL_PASS_COUNT=$PASS_COUNT
FINAL_FAIL_COUNT=$FAIL_COUNT
FINAL_WARN_COUNT=$WARN_COUNT

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Test Results Summary${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}PASS: $FINAL_PASS_COUNT${NC}"
echo -e "${RED}FAIL: $FINAL_FAIL_COUNT${NC}"
echo -e "${YELLOW}WARN: $FINAL_WARN_COUNT${NC}"
echo ""
total_tests=$(($FINAL_PASS_COUNT + $FINAL_FAIL_COUNT + $FINAL_WARN_COUNT))
if [ $total_tests -gt 0 ]; then
    score_percentage=$(($FINAL_PASS_COUNT * 100 / total_tests))
else
    score_percentage=0
fi
print_status "INFO" "Environment Score: ${score_percentage}% ($FINAL_PASS_COUNT/$total_tests tests passed)"
echo ""

# Write results to JSON using the final counts
PASS_COUNT=$FINAL_PASS_COUNT
FAIL_COUNT=$FINAL_FAIL_COUNT
WARN_COUNT=$FINAL_WARN_COUNT
write_results_to_json

if [ $FINAL_FAIL_COUNT -eq 0 ]; then
    print_status "INFO" "All tests passed! Your Fairify environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your Fairify environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi

print_status "INFO" "You can now run Fairify neural network fairness verification."
print_status "INFO" "Example: cd src && ./fairify.sh GC"

echo ""
print_status "INFO" "For more information, see README.md and INSTALL.md"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/EnvGym/data/Fairify fairify-env-test /bin/bash" 