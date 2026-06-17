#!/bin/bash
# CrossPrefetch Environment Benchmark Test
# Tests if the environment is properly set up for the CrossPrefetch Linux kernel modification project
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

# Function to check kernel version
check_kernel_version() {
    local kernel_version=$(uname -r 2>&1)
    print_status "INFO" "Current kernel version: $kernel_version"
    
    # Extract version number
    local version=$(uname -r | cut -d'-' -f1)
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -eq 5 ] && [ "$minor" -ge 14 ]; then
        print_status "PASS" "Kernel version >= 5.14 (found $version)"
    else
        print_status "WARN" "Kernel version < 5.14 (found $version) - may need kernel upgrade"
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
        echo "ERROR: envgym.dockerfile not found. Please run this script from the CrossPrefetch project root directory."
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo "Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t crossprefetch-env-test .; then
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
    docker run --rm -v "$(pwd):/home/cc/EnvGym/data/CrossPrefetch" crossprefetch-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        ./envgym/envbench.sh
    "
    exit 0
fi

echo "=========================================="
echo "CrossPrefetch Environment Benchmark Test"
echo "=========================================="
echo ""

echo "1. Checking System Dependencies..."
echo "--------------------------------"
# Check system commands
check_command "gcc" "GCC Compiler"
check_command "g++" "G++ Compiler"
check_command "make" "Make"
check_command "git" "Git"
check_command "bash" "Bash"
check_command "cmake" "CMake"
check_command "python3" "Python 3"
check_command "pip3" "pip3"
check_command "numactl" "numactl"
check_command "perf" "perf"

echo ""
echo "2. Checking Kernel Environment..."
echo "--------------------------------"
check_kernel_version

# Check kernel headers
if [ -d "/usr/src/linux-headers-$(uname -r)" ]; then
    print_status "PASS" "Kernel headers are installed"
else
    print_status "FAIL" "Kernel headers are not installed"
fi

# Check if we can build kernel modules
if [ -f "/lib/modules/$(uname -r)/build/Makefile" ]; then
    print_status "PASS" "Kernel build environment is available"
else
    print_status "FAIL" "Kernel build environment is not available"
fi

echo ""
echo "3. Checking Project Structure..."
echo "-------------------------------"
# Check if we're in the right directory
if [ -f "README.md" ]; then
    print_status "PASS" "README.md found"
else
    print_status "FAIL" "README.md not found"
    exit 1
fi

# Check if we're in the CrossPrefetch project
if grep -q "CrossPrefetch" README.md 2>/dev/null; then
    print_status "PASS" "CrossPrefetch project detected"
else
    print_status "FAIL" "Not a CrossPrefetch project"
fi

# Check project structure
print_status "INFO" "Checking project structure..."

if [ -d "linux-5.14.0" ]; then
    print_status "PASS" "linux-5.14.0 directory exists"
else
    print_status "FAIL" "linux-5.14.0 directory missing"
fi

if [ -d "scripts" ]; then
    print_status "PASS" "scripts directory exists"
else
    print_status "FAIL" "scripts directory missing"
fi

if [ -d "shared_libs" ]; then
    print_status "PASS" "shared_libs directory exists"
else
    print_status "FAIL" "shared_libs directory missing"
fi

if [ -d "appbench" ]; then
    print_status "PASS" "appbench directory exists"
else
    print_status "FAIL" "appbench directory missing"
fi

echo ""
echo "4. Checking Linux Kernel Source..."
echo "---------------------------------"
# Check Linux kernel source
if [ -d "linux-5.14.0" ]; then
    if [ -f "linux-5.14.0/Makefile" ]; then
        print_status "PASS" "linux-5.14.0/Makefile exists"
    else
        print_status "FAIL" "linux-5.14.0/Makefile missing"
    fi
    
    if [ -f "linux-5.14.0/.config" ]; then
        print_status "PASS" "linux-5.14.0/.config exists"
    else
        print_status "WARN" "linux-5.14.0/.config missing (may need configuration)"
    fi
    
    if [ -d "linux-5.14.0/arch" ]; then
        print_status "PASS" "linux-5.14.0/arch directory exists"
    else
        print_status "FAIL" "linux-5.14.0/arch directory missing"
    fi
    
    if [ -d "linux-5.14.0/kernel" ]; then
        print_status "PASS" "linux-5.14.0/kernel directory exists"
    else
        print_status "FAIL" "linux-5.14.0/kernel directory missing"
    fi
    
    if [ -d "linux-5.14.0/fs" ]; then
        print_status "PASS" "linux-5.14.0/fs directory exists"
    else
        print_status "FAIL" "linux-5.14.0/fs directory missing"
    fi
fi

echo ""
echo "5. Checking Scripts..."
echo "---------------------"
# Check scripts
if [ -d "scripts" ]; then
    if [ -f "scripts/setvars.sh" ]; then
        print_status "PASS" "scripts/setvars.sh exists"
    else
        print_status "FAIL" "scripts/setvars.sh missing"
    fi
    
    if [ -f "scripts/install_packages.sh" ]; then
        print_status "PASS" "scripts/install_packages.sh exists"
    else
        print_status "FAIL" "scripts/install_packages.sh missing"
    fi
    
    if [ -f "scripts/run_all.sh" ]; then
        print_status "PASS" "scripts/run_all.sh exists"
    else
        print_status "FAIL" "scripts/run_all.sh missing"
    fi
    
    if [ -d "scripts/run" ]; then
        print_status "PASS" "scripts/run directory exists"
    else
        print_status "FAIL" "scripts/run directory missing"
    fi
fi

echo ""
echo "6. Checking Shared Libraries..."
echo "-------------------------------"
# Check shared libraries
if [ -d "shared_libs" ]; then
    if [ -d "shared_libs/simple_prefetcher" ]; then
        print_status "PASS" "shared_libs/simple_prefetcher directory exists"
        
        if [ -f "shared_libs/simple_prefetcher/compile.sh" ]; then
            print_status "PASS" "shared_libs/simple_prefetcher/compile.sh exists"
        else
            print_status "FAIL" "shared_libs/simple_prefetcher/compile.sh missing"
        fi
    else
        print_status "FAIL" "shared_libs/simple_prefetcher directory missing"
    fi
fi

echo ""
echo "7. Checking AppBench Applications..."
echo "-----------------------------------"
# Check appbench applications
if [ -d "appbench" ]; then
    if [ -d "appbench/apps" ]; then
        print_status "PASS" "appbench/apps directory exists"
        
        # Check for specific applications
        app_count=$(find appbench/apps -maxdepth 1 -type d | wc -l)
        print_status "INFO" "Found $app_count application directories in appbench/apps"
        
        if [ "$app_count" -gt 1 ]; then
            print_status "PASS" "Application directories found"
        else
            print_status "WARN" "No application directories found"
        fi
    else
        print_status "FAIL" "appbench/apps directory missing"
    fi
    
    if [ -f "appbench/cleanall.sh" ]; then
        print_status "PASS" "appbench/cleanall.sh exists"
    else
        print_status "FAIL" "appbench/cleanall.sh missing"
    fi
fi

echo ""
echo "8. Testing Environment Variables..."
echo "----------------------------------"
# Test environment variables setup
if [ -f "scripts/setvars.sh" ]; then
    print_status "INFO" "Testing environment variables setup..."
    
    # Source the setvars.sh script
    if source scripts/setvars.sh 2>/dev/null; then
        print_status "PASS" "setvars.sh can be sourced successfully"
        
        # Check key environment variables
        if [ -n "$BASE" ]; then
            print_status "PASS" "BASE environment variable is set: $BASE"
        else
            print_status "FAIL" "BASE environment variable is not set"
        fi
        
        if [ -n "$KERN_SRC" ]; then
            print_status "PASS" "KERN_SRC environment variable is set: $KERN_SRC"
        else
            print_status "FAIL" "KERN_SRC environment variable is not set"
        fi
        
        if [ -n "$APPBENCH" ]; then
            print_status "PASS" "APPBENCH environment variable is set: $APPBENCH"
        else
            print_status "FAIL" "APPBENCH environment variable is not set"
        fi
        
        if [ -n "$SHARED_LIBS" ]; then
            print_status "PASS" "SHARED_LIBS environment variable is set: $SHARED_LIBS"
        else
            print_status "FAIL" "SHARED_LIBS environment variable is not set"
        fi
    else
        print_status "FAIL" "setvars.sh cannot be sourced"
    fi
fi

echo ""
echo "9. Testing System Libraries..."
echo "-----------------------------"
# Test system libraries
print_status "INFO" "Testing system libraries..."

# Test ncurses
if pkg-config --exists ncurses 2>/dev/null; then
    print_status "PASS" "ncurses development libraries are available"
else
    print_status "FAIL" "ncurses development libraries are not available"
fi

# Test boost
if pkg-config --exists boost 2>/dev/null; then
    print_status "PASS" "boost development libraries are available"
else
    print_status "WARN" "boost development libraries are not available"
fi

# Test numa
if pkg-config --exists numa 2>/dev/null; then
    print_status "PASS" "numa development libraries are available"
else
    print_status "FAIL" "numa development libraries are not available"
fi

# Test config
if pkg-config --exists libconfig 2>/dev/null; then
    print_status "PASS" "libconfig development libraries are available"
else
    print_status "WARN" "libconfig development libraries are not available"
fi

# Test zstd
if pkg-config --exists libzstd 2>/dev/null; then
    print_status "PASS" "zstd development libraries are available"
else
    print_status "WARN" "zstd development libraries are not available"
fi

# Test lz4
if pkg-config --exists liblz4 2>/dev/null; then
    print_status "PASS" "lz4 development libraries are available"
else
    print_status "WARN" "lz4 development libraries are not available"
fi

# Test snappy
if pkg-config --exists snappy 2>/dev/null; then
    print_status "PASS" "snappy development libraries are available"
else
    print_status "WARN" "snappy development libraries are not available"
fi

# Test ssl
if pkg-config --exists openssl 2>/dev/null; then
    print_status "PASS" "openssl development libraries are available"
else
    print_status "WARN" "openssl development libraries are not available"
fi

# Test gflags
if pkg-config --exists gflags 2>/dev/null; then
    print_status "PASS" "gflags development libraries are available"
else
    print_status "WARN" "gflags development libraries are not available"
fi

# Test zlib
if pkg-config --exists zlib 2>/dev/null; then
    print_status "PASS" "zlib development libraries are available"
else
    print_status "WARN" "zlib development libraries are not available"
fi

# Test bzip2
if pkg-config --exists bzip2 2>/dev/null; then
    print_status "PASS" "bzip2 development libraries are available"
else
    print_status "WARN" "bzip2 development libraries are not available"
fi

# Test libevent
if pkg-config --exists libevent 2>/dev/null; then
    print_status "PASS" "libevent development libraries are available"
else
    print_status "WARN" "libevent development libraries are not available"
fi

# Test jemalloc
if pkg-config --exists jemalloc 2>/dev/null; then
    print_status "PASS" "jemalloc development libraries are available"
else
    print_status "WARN" "jemalloc development libraries are not available"
fi

echo ""
echo "10. Testing NVMe Storage..."
echo "---------------------------"
# Test NVMe storage
print_status "INFO" "Testing NVMe storage..."

# Check if NVMe devices exist
if ls /dev/nvme* 2>/dev/null | grep -q nvme; then
    print_status "PASS" "NVMe devices are available"
    
    # List NVMe devices
    nvme_devices=$(ls /dev/nvme* 2>/dev/null | grep nvme)
    print_status "INFO" "NVMe devices found: $nvme_devices"
else
    print_status "WARN" "No NVMe devices found (may be running in VM/container)"
fi

# Check if we can access NVMe
if command -v nvme &> /dev/null; then
    print_status "PASS" "nvme command line tool is available"
else
    print_status "WARN" "nvme command line tool is not available"
fi

# Check if we have write access to /dev/nvme*
if [ -w "/dev/nvme0n1" ] 2>/dev/null; then
    print_status "PASS" "Have write access to NVMe device"
else
    print_status "WARN" "No write access to NVMe device (may need sudo)"
fi

echo ""
echo "11. Testing Compilation Environment..."
echo "-------------------------------------"
# Test compilation environment
print_status "INFO" "Testing compilation environment..."

# Test basic C compilation
if echo 'int main() { return 0; }' | gcc -x c - -o /tmp/test_compile 2>/dev/null; then
    print_status "PASS" "Basic C compilation works"
    rm -f /tmp/test_compile
else
    print_status "FAIL" "Basic C compilation failed"
fi

# Test basic C++ compilation
if echo 'int main() { return 0; }' | g++ -x c++ - -o /tmp/test_compile 2>/dev/null; then
    print_status "PASS" "Basic C++ compilation works"
    rm -f /tmp/test_compile
else
    print_status "FAIL" "Basic C++ compilation failed"
fi

# Test make
if make --version >/dev/null 2>&1; then
    print_status "PASS" "Make is working"
else
    print_status "FAIL" "Make is not working"
fi

# Test cmake
if cmake --version >/dev/null 2>&1; then
    print_status "PASS" "CMake is working"
else
    print_status "FAIL" "CMake is not working"
fi

echo ""
echo "12. Testing Python Dependencies..."
echo "---------------------------------"
# Test Python dependencies
print_status "INFO" "Testing Python dependencies..."

# Test psutil
if python3 -c "import psutil" 2>/dev/null; then
    print_status "PASS" "psutil is available"
else
    print_status "FAIL" "psutil is not available"
fi

# Test zplot
if python3 -c "import zplot" 2>/dev/null; then
    print_status "PASS" "zplot is available"
else
    print_status "WARN" "zplot is not available"
fi

echo ""
echo "13. Testing System Tools..."
echo "---------------------------"
# Test system tools
check_command "msr-tools" "msr-tools"
check_command "cscope" "cscope"
check_command "numactl" "numactl"
check_command "perf" "perf"

# Test if we can access MSR registers
if [ -r "/dev/cpu/0/msr" ] 2>/dev/null; then
    print_status "PASS" "MSR registers are accessible"
else
    print_status "WARN" "MSR registers are not accessible (may need sudo)"
fi

echo ""
echo "14. Testing Git Configuration..."
echo "--------------------------------"
# Check Git configuration
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

echo ""
echo "15. Testing Locale Configuration..."
echo "-----------------------------------"
# Test locale configuration
if [ "$LANG" = "C.UTF-8" ] || [ "$LANG" = "en_US.UTF-8" ]; then
    print_status "PASS" "LANG is set to UTF-8 locale"
else
    print_status "WARN" "LANG is not set to UTF-8 locale (current: $LANG)"
fi

if [ "$LC_ALL" = "C.UTF-8" ] || [ "$LC_ALL" = "en_US.UTF-8" ]; then
    print_status "PASS" "LC_ALL is set to UTF-8 locale"
else
    print_status "WARN" "LC_ALL is not set to UTF-8 locale (current: $LC_ALL)"
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
echo "- System dependencies (GCC, Make, CMake, Git, Python)"
echo "- Kernel environment and headers"
echo "- Project structure and directories"
echo "- Linux kernel source code"
echo "- Scripts and environment variables"
echo "- Shared libraries and applications"
echo "- System libraries (ncurses, boost, numa, etc.)"
echo "- NVMe storage access"
echo "- Compilation environment"
echo "- Python dependencies"
echo "- System tools (msr-tools, cscope, numactl, perf)"
echo "- Git repository setup"
echo "- Locale configuration"
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
    print_status "INFO" "All tests passed! Your CrossPrefetch environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your CrossPrefetch environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi

print_status "INFO" "You can now compile and test CrossPrefetch."
print_status "INFO" "Example: source scripts/setvars.sh"
print_status "INFO" "Example: cd linux-5.14.0 && ./compile_modified_deb.sh"

echo ""
print_status "INFO" "For more information, see README.md"
print_status "INFO" "This project requires NVMe storage and kernel compilation capabilities"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/EnvGym/data/CrossPrefetch crossprefetch-env-test /bin/bash" 