#!/bin/bash

# Facebook Zstandard Environment Benchmark Test Script
# This script tests the environment setup for Zstandard compression library

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize counters
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

# Check if envgym.dockerfile exists (only when not in Docker container)
if [ ! -f /.dockerenv ] && ! grep -q docker /proc/1/cgroup 2>/dev/null; then
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
    esac
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Kill any background processes
    jobs -p | xargs -r kill
    # Remove temporary files
    rm -f docker_build.log
    # Stop and remove Docker container if running
    docker stop zstd-env-test 2>/dev/null || true
    docker rm zstd-env-test 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

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
        echo "ERROR: envgym.dockerfile not found. Please run this script from the facebook_zstd project root directory."
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo "Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t zstd-env-test .; then
        echo -e "${RED}[CRITICAL ERROR]${NC} Docker build failed"
        echo -e "${RED}[RESULT]${NC} Benchmark score: 0 (Docker build failed)"
        # Only write 0 0 0 to JSON if the file doesn't exist or is empty
        if [ ! -f "envgym/envbench.json" ] || [ ! -s "envgym/envbench.json" ]; then
            PASS_COUNT=0
            FAIL_COUNT=0
            WARN_COUNT=0
            write_results_to_json
        fi
        exit 1
    fi
    
    # Run this script inside Docker container
    echo "Running environment test in Docker container..."
    docker run --rm -v "$(pwd):/home/cc/EnvGym/data/facebook_zstd" zstd-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        ./envgym/envbench.sh
    "
    exit 0
fi

echo "=========================================="
echo "Zstandard Environment Benchmark Test"
echo "=========================================="

# Analyze Dockerfile if build failed
if [ "${DOCKER_BUILD_FAILED:-false}" = "true" ]; then
    echo ""
    echo "Analyzing Dockerfile..."
    echo "----------------------"
    
    if [ -f "envgym/envgym.dockerfile" ]; then
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
        
        if grep -q "build-essential" envgym/envgym.dockerfile; then
            print_status "PASS" "build-essential found"
        else
            print_status "FAIL" "build-essential not found"
        fi
        
        if grep -q "cmake" envgym/envgym.dockerfile; then
            print_status "PASS" "cmake found"
        else
            print_status "WARN" "cmake not found"
        fi
        
        if grep -q "make" envgym/envgym.dockerfile; then
            print_status "PASS" "make found"
        else
            print_status "FAIL" "make not found"
        fi
        
        if grep -q "g++" envgym/envgym.dockerfile; then
            print_status "PASS" "g++ found"
        else
            print_status "FAIL" "g++ not found"
        fi
        
        if grep -q "python3" envgym/envgym.dockerfile; then
            print_status "PASS" "python3 found"
        else
            print_status "WARN" "python3 not found"
        fi
        
        if grep -q "git" envgym/envgym.dockerfile; then
            print_status "PASS" "git found"
        else
            print_status "WARN" "git not found"
        fi
        
        if grep -q "ninja-build" envgym/envgym.dockerfile; then
            print_status "PASS" "ninja-build found"
        else
            print_status "WARN" "ninja-build not found"
        fi
        
        if grep -q "libgtest-dev" envgym/envgym.dockerfile; then
            print_status "PASS" "libgtest-dev found"
        else
            print_status "WARN" "libgtest-dev not found"
        fi
        
        if grep -q "COPY" envgym/envgym.dockerfile; then
            print_status "PASS" "COPY instruction found"
        else
            print_status "WARN" "COPY instruction not found"
        fi
        
        if grep -q "RUN make" envgym/envgym.dockerfile; then
            print_status "PASS" "make build found"
        else
            print_status "FAIL" "make build not found"
        fi
        
        if grep -q "CMD" envgym/envgym.dockerfile; then
            print_status "PASS" "CMD instruction found"
        else
            print_status "WARN" "CMD instruction not found"
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
        echo ""
    else
        print_status "FAIL" "envgym.dockerfile not found"
    fi
fi

echo "1. Checking System Dependencies..."
echo "--------------------------------"
# Check C compiler
if command -v gcc &> /dev/null; then
    gcc_version=$(gcc --version 2>&1 | head -n 1)
    print_status "PASS" "GCC is available: $gcc_version"
else
    print_status "FAIL" "GCC is not available"
fi

# Check C++ compiler
if command -v g++ &> /dev/null; then
    gpp_version=$(g++ --version 2>&1 | head -n 1)
    print_status "PASS" "G++ is available: $gpp_version"
else
    print_status "FAIL" "G++ is not available"
fi

# Check Make
if command -v make &> /dev/null; then
    make_version=$(make --version 2>&1 | head -n 1)
    print_status "PASS" "Make is available: $make_version"
else
    print_status "FAIL" "Make is not available"
fi

# Check CMake
if command -v cmake &> /dev/null; then
    cmake_version=$(cmake --version 2>&1 | head -n 1)
    print_status "PASS" "CMake is available: $cmake_version"
else
    print_status "WARN" "CMake is not available"
fi

# Check Ninja
if command -v ninja &> /dev/null; then
    ninja_version=$(ninja --version 2>&1)
    print_status "PASS" "Ninja is available: $ninja_version"
else
    print_status "WARN" "Ninja is not available"
fi

# Check Python3
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version 2>&1)
    print_status "PASS" "Python3 is available: $python_version"
else
    print_status "WARN" "Python3 is not available"
fi

# Check pip3
if command -v pip3 &> /dev/null; then
    pip_version=$(pip3 --version 2>&1)
    print_status "PASS" "pip3 is available: $pip_version"
else
    print_status "WARN" "pip3 is not available"
fi

# Check Git
if command -v git &> /dev/null; then
    git_version=$(git --version 2>&1)
    print_status "PASS" "Git is available: $git_version"
else
    print_status "FAIL" "Git is not available"
fi

# Check curl
if command -v curl &> /dev/null; then
    print_status "PASS" "curl is available"
else
    print_status "FAIL" "curl is not available"
fi

# Check wget
if command -v wget &> /dev/null; then
    print_status "PASS" "wget is available"
else
    print_status "WARN" "wget is not available"
fi

# Check pkg-config
if command -v pkg-config &> /dev/null; then
    print_status "PASS" "pkg-config is available"
else
    print_status "WARN" "pkg-config is not available"
fi

echo ""
echo "2. Checking Project Structure..."
echo "-------------------------------"
# Check main directories
if [ -d "lib" ]; then
    print_status "PASS" "lib directory exists"
else
    print_status "FAIL" "lib directory not found"
fi

if [ -d "programs" ]; then
    print_status "PASS" "programs directory exists"
else
    print_status "FAIL" "programs directory not found"
fi

if [ -d "tests" ]; then
    print_status "PASS" "tests directory exists"
else
    print_status "FAIL" "tests directory not found"
fi

if [ -d "examples" ]; then
    print_status "PASS" "examples directory exists"
else
    print_status "FAIL" "examples directory not found"
fi

if [ -d "doc" ]; then
    print_status "PASS" "doc directory exists"
else
    print_status "FAIL" "doc directory not found"
fi

if [ -d "contrib" ]; then
    print_status "PASS" "contrib directory exists"
else
    print_status "FAIL" "contrib directory not found"
fi

if [ -d "zlibWrapper" ]; then
    print_status "PASS" "zlibWrapper directory exists"
else
    print_status "FAIL" "zlibWrapper directory not found"
fi

# Check key files
if [ -f "Makefile" ]; then
    print_status "PASS" "Makefile exists"
else
    print_status "FAIL" "Makefile not found"
fi

if [ -f "README.md" ]; then
    print_status "PASS" "README.md exists"
else
    print_status "FAIL" "README.md not found"
fi

if [ -f "LICENSE" ]; then
    print_status "PASS" "LICENSE exists"
else
    print_status "FAIL" "LICENSE not found"
fi

if [ -f "COPYING" ]; then
    print_status "PASS" "COPYING exists"
else
    print_status "FAIL" "COPYING not found"
fi

if [ -f "CHANGELOG" ]; then
    print_status "PASS" "CHANGELOG exists"
else
    print_status "FAIL" "CHANGELOG not found"
fi

if [ -f "Package.swift" ]; then
    print_status "PASS" "Package.swift exists"
else
    print_status "FAIL" "Package.swift not found"
fi

# Check lib files
if [ -f "lib/zstd.h" ]; then
    print_status "PASS" "lib/zstd.h exists"
else
    print_status "FAIL" "lib/zstd.h not found"
fi

if [ -f "lib/zdict.h" ]; then
    print_status "PASS" "lib/zdict.h exists"
else
    print_status "FAIL" "lib/zdict.h not found"
fi

if [ -f "lib/zstd_errors.h" ]; then
    print_status "PASS" "lib/zstd_errors.h exists"
else
    print_status "FAIL" "lib/zstd_errors.h not found"
fi

if [ -f "lib/Makefile" ]; then
    print_status "PASS" "lib/Makefile exists"
else
    print_status "FAIL" "lib/Makefile not found"
fi

# Check programs files
if [ -f "programs/zstdcli.c" ]; then
    print_status "PASS" "programs/zstdcli.c exists"
else
    print_status "FAIL" "programs/zstdcli.c not found"
fi

if [ -f "programs/Makefile" ]; then
    print_status "PASS" "programs/Makefile exists"
else
    print_status "FAIL" "programs/Makefile not found"
fi

if [ -f "programs/benchzstd.c" ]; then
    print_status "PASS" "programs/benchzstd.c exists"
else
    print_status "FAIL" "programs/benchzstd.c not found"
fi

if [ -f "programs/datagen.c" ]; then
    print_status "PASS" "programs/datagen.c exists"
else
    print_status "FAIL" "programs/datagen.c not found"
fi

# Check test files
if [ -f "tests/Makefile" ]; then
    print_status "PASS" "tests/Makefile exists"
else
    print_status "FAIL" "tests/Makefile not found"
fi

if [ -f "tests/playTests.sh" ]; then
    print_status "PASS" "tests/playTests.sh exists"
else
    print_status "FAIL" "tests/playTests.sh not found"
fi

if [ -f "tests/fullbench.c" ]; then
    print_status "PASS" "tests/fullbench.c exists"
else
    print_status "FAIL" "tests/fullbench.c not found"
fi

echo ""
echo "3. Checking Environment Variables..."
echo "-----------------------------------"
# Check C compiler environment
if [ -n "${CC:-}" ]; then
    print_status "PASS" "CC is set: $CC"
else
    print_status "WARN" "CC is not set"
fi

if [ -n "${CXX:-}" ]; then
    print_status "PASS" "CXX is set: $CXX"
else
    print_status "WARN" "CXX is not set"
fi

# Check build environment
if [ -n "${CFLAGS:-}" ]; then
    print_status "PASS" "CFLAGS is set: $CFLAGS"
else
    print_status "WARN" "CFLAGS is not set"
fi

if [ -n "${CXXFLAGS:-}" ]; then
    print_status "PASS" "CXXFLAGS is set: $CXXFLAGS"
else
    print_status "WARN" "CXXFLAGS is not set"
fi

if [ -n "${LDFLAGS:-}" ]; then
    print_status "PASS" "LDFLAGS is set: $LDFLAGS"
else
    print_status "WARN" "LDFLAGS is not set"
fi

# Check PATH
if echo "$PATH" | grep -q "gcc"; then
    print_status "PASS" "GCC is in PATH"
else
    print_status "WARN" "GCC is not in PATH"
fi

if echo "$PATH" | grep -q "make"; then
    print_status "PASS" "Make is in PATH"
else
    print_status "WARN" "Make is not in PATH"
fi

echo ""
echo "4. Testing C/C++ Compilation..."
echo "-------------------------------"
# Test C compilation
if command -v gcc &> /dev/null; then
    print_status "PASS" "gcc is available"
    
    # Test simple C compilation
    echo '#include <stdio.h>
int main() { printf("Hello from C\n"); return 0; }' > test.c
    
    if gcc -o test_c test.c 2>/dev/null; then
        print_status "PASS" "C compilation works"
        if ./test_c >/dev/null 2>&1; then
            print_status "PASS" "C program execution works"
        else
            print_status "WARN" "C program execution failed"
        fi
        rm -f test_c test.c
    else
        print_status "WARN" "C compilation failed"
        rm -f test.c
    fi
else
    print_status "FAIL" "gcc is not available"
fi

# Test C++ compilation
if command -v g++ &> /dev/null; then
    print_status "PASS" "g++ is available"
    
    # Test simple C++ compilation
    echo '#include <iostream>
int main() { std::cout << "Hello from C++" << std::endl; return 0; }' > test.cpp
    
    if g++ -o test_cpp test.cpp 2>/dev/null; then
        print_status "PASS" "C++ compilation works"
        if ./test_cpp >/dev/null 2>&1; then
            print_status "PASS" "C++ program execution works"
        else
            print_status "WARN" "C++ program execution failed"
        fi
        rm -f test_cpp test.cpp
    else
        print_status "WARN" "C++ compilation failed"
        rm -f test.cpp
    fi
else
    print_status "FAIL" "g++ is not available"
fi

echo ""
echo "5. Testing Make Build System..."
echo "-------------------------------"
# Test Make
if command -v make &> /dev/null && [ -f "Makefile" ]; then
    print_status "PASS" "make and Makefile are available"
    
    # Test make help or version
    if timeout 30s make --version >/dev/null 2>&1; then
        print_status "PASS" "make version command works"
    else
        print_status "WARN" "make version command failed"
    fi
    
    # Test make help (if available)
    if timeout 30s make help >/dev/null 2>&1; then
        print_status "PASS" "make help command works"
    else
        print_status "WARN" "make help command not available"
    fi
else
    print_status "WARN" "make or Makefile not available"
fi

echo ""
echo "6. Testing CMake Build System..."
echo "--------------------------------"
# Test CMake
if command -v cmake &> /dev/null; then
    print_status "PASS" "cmake is available"
    
    # Test cmake version
    if timeout 30s cmake --version >/dev/null 2>&1; then
        print_status "PASS" "cmake version command works"
    else
        print_status "WARN" "cmake version command failed"
    fi
    
    # Test cmake help
    if timeout 30s cmake --help >/dev/null 2>&1; then
        print_status "PASS" "cmake help command works"
    else
        print_status "WARN" "cmake help command failed"
    fi
else
    print_status "WARN" "cmake is not available"
fi

echo ""
echo "7. Testing Python Environment..."
echo "--------------------------------"
# Test Python3
if command -v python3 &> /dev/null; then
    print_status "PASS" "python3 is available"
    
    # Test Python3 execution
    if timeout 30s python3 -c "print('Hello from Python3')" >/dev/null 2>&1; then
        print_status "PASS" "Python3 execution works"
    else
        print_status "WARN" "Python3 execution failed"
    fi
    
    # Test pip3
    if command -v pip3 &> /dev/null; then
        print_status "PASS" "pip3 is available"
        
        # Test pip3 list
        if timeout 30s pip3 list >/dev/null 2>&1; then
            print_status "PASS" "pip3 list command works"
        else
            print_status "WARN" "pip3 list command failed"
        fi
    else
        print_status "WARN" "pip3 is not available"
    fi
else
    print_status "WARN" "python3 is not available"
fi

echo ""
echo "8. Testing Library Dependencies..."
echo "----------------------------------"
# Test pkg-config for various libraries
if command -v pkg-config &> /dev/null; then
    print_status "PASS" "pkg-config is available"
    
    # Test zlib
    if pkg-config --exists zlib 2>/dev/null; then
        print_status "PASS" "zlib development files available"
    else
        print_status "WARN" "zlib development files not found"
    fi
    
    # Test lz4
    if pkg-config --exists liblz4 2>/dev/null; then
        print_status "PASS" "lz4 development files available"
    else
        print_status "WARN" "lz4 development files not found"
    fi
    
    # Test snappy
    if pkg-config --exists snappy 2>/dev/null; then
        print_status "PASS" "snappy development files available"
    else
        print_status "WARN" "snappy development files not found"
    fi
    
    # Test lzo2
    if pkg-config --exists lzo2 2>/dev/null; then
        print_status "PASS" "lzo2 development files available"
    else
        print_status "WARN" "lzo2 development files not found"
    fi
else
    print_status "WARN" "pkg-config is not available"
fi

echo ""
echo "9. Testing Zstandard Library..."
echo "-------------------------------"
# Test if zstd.h can be compiled
if command -v gcc &> /dev/null && [ -f "lib/zstd.h" ]; then
    print_status "PASS" "gcc and zstd.h are available"
    
    # Test zstd.h compilation
    echo '#include "lib/zstd.h"
#include <stdio.h>
int main() { 
    printf("ZSTD version: %s\n", ZSTD_VERSION_STRING); 
    return 0; 
}' > test_zstd.c
    
    if gcc -I. -o test_zstd test_zstd.c 2>/dev/null; then
        print_status "PASS" "zstd.h compilation works"
        if ./test_zstd >/dev/null 2>&1; then
            print_status "PASS" "zstd program execution works"
        else
            print_status "WARN" "zstd program execution failed"
        fi
        rm -f test_zstd test_zstd.c
    else
        print_status "WARN" "zstd.h compilation failed"
        rm -f test_zstd.c
    fi
else
    print_status "WARN" "gcc or zstd.h not available"
fi

echo ""
echo "10. Testing Build Process..."
echo "----------------------------"
# Test make build
if command -v make &> /dev/null && [ -f "Makefile" ]; then
    print_status "PASS" "make and Makefile are available for build testing"
    
    # Test make lib (library build)
    if timeout 120s make lib >/dev/null 2>&1; then
        print_status "PASS" "Library build successful"
    else
        print_status "WARN" "Library build failed or timed out"
    fi
    
    # Check if library files were created
    if [ -f "lib/libzstd.a" ] || [ -f "lib/libzstd.so" ]; then
        print_status "PASS" "Library files created"
    else
        print_status "WARN" "Library files not found"
    fi
else
    print_status "WARN" "make or Makefile not available for build testing"
fi

echo ""
echo "11. Testing Zstd Binary..."
echo "---------------------------"
# Test if zstd binary exists or can be built
if [ -f "zstd" ] && [ -x "zstd" ]; then
    print_status "PASS" "zstd binary exists and is executable"
    
    # Test zstd version
    if timeout 30s ./zstd --version >/dev/null 2>&1; then
        print_status "PASS" "zstd version command works"
    else
        print_status "WARN" "zstd version command failed"
    fi
    
    # Test zstd help
    if timeout 30s ./zstd --help >/dev/null 2>&1; then
        print_status "PASS" "zstd help command works"
    else
        print_status "WARN" "zstd help command failed"
    fi
else
    print_status "WARN" "zstd binary not found or not executable"
    
    # Try to build zstd binary
    if command -v make &> /dev/null && [ -f "Makefile" ]; then
        print_status "INFO" "Attempting to build zstd binary..."
        if timeout 180s make zstd >/dev/null 2>&1; then
            if [ -f "zstd" ] && [ -x "zstd" ]; then
                print_status "PASS" "zstd binary built successfully"
                
                # Test zstd version
                if timeout 30s ./zstd --version >/dev/null 2>&1; then
                    print_status "PASS" "zstd version command works"
                else
                    print_status "WARN" "zstd version command failed"
                fi
            else
                print_status "WARN" "zstd binary build failed"
            fi
        else
            print_status "WARN" "zstd binary build failed or timed out"
        fi
    else
        print_status "WARN" "make not available for building zstd binary"
    fi
fi

echo ""
echo "12. Testing Compression Tools..."
echo "--------------------------------"
# Test compression tools availability
if command -v lz4 &> /dev/null; then
    print_status "PASS" "lz4 tool is available"
else
    print_status "WARN" "lz4 tool is not available"
fi

if command -v brotli &> /dev/null; then
    print_status "PASS" "brotli tool is available"
else
    print_status "WARN" "brotli tool is not available"
fi

if command -v gzip &> /dev/null; then
    print_status "PASS" "gzip tool is available"
else
    print_status "WARN" "gzip tool is not available"
fi

echo ""
echo "=========================================="
echo "Environment Benchmark Test Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "--------"
echo "This script has tested:"
echo "- System dependencies (GCC, G++, Make, CMake, Ninja, Python3)"
echo "- Project structure (lib/, programs/, tests/, examples/)"
echo "- Environment variables (CC, CXX, CFLAGS, CXXFLAGS, LDFLAGS)"
echo "- C/C++ compilation (gcc, g++)"
echo "- Build systems (Make, CMake)"
echo "- Python environment (python3, pip3)"
echo "- Library dependencies (zlib, lz4, snappy, lzo2)"
echo "- Zstandard library (zstd.h compilation)"
echo "- Build process (library and binary compilation)"
echo "- Zstd binary (version, help commands)"
echo "- Compression tools (lz4, brotli, gzip)"
echo "- Dockerfile structure (if Docker build failed)"

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
    print_status "INFO" "All tests passed! Your Zstandard environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your Zstandard environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi

print_status "INFO" "You can now build and test Zstandard compression library."
print_status "INFO" "Example: make && make check"

echo ""
print_status "INFO" "For more information, see README.md"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/EnvGym/data/facebook_zstd zstd-env-test /bin/bash" 