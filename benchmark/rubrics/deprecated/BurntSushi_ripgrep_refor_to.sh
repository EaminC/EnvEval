#!/bin/bash
# BurntSushi_ripgrep Environment Benchmark Test
# Tests if the environment is properly set up for the ripgrep Rust search tool project
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

# Function to check Rust version
check_rust_version() {
    local rust_version=$(rustc --version 2>&1)
    print_status "INFO" "Rust version: $rust_version"
    
    # Extract version number
    local version=$(rustc --version | sed 's/rustc //' | sed 's/ .*//')
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -eq 1 ] && [ "$minor" -ge 72 ]; then
        print_status "PASS" "Rust version >= 1.72 (found $version)"
    else
        print_status "FAIL" "Rust version < 1.72 (found $version)"
    fi
}

# Function to check Cargo version
check_cargo_version() {
    local cargo_version=$(cargo --version 2>&1)
    print_status "INFO" "Cargo version: $cargo_version"
    
    # Extract version number
    local version=$(cargo --version | sed 's/cargo //' | sed 's/ .*//')
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -eq 1 ] && [ "$minor" -ge 72 ]; then
        print_status "PASS" "Cargo version >= 1.72 (found $version)"
    else
        print_status "FAIL" "Cargo version < 1.72 (found $version)"
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
        echo "ERROR: envgym.dockerfile not found. Please run this script from the BurntSushi_ripgrep project root directory."
        # Write 0 0 0 to JSON
        PASS_COUNT=0
        FAIL_COUNT=0
        WARN_COUNT=0
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo "Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t ripgrep-env-test .; then
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
    docker run --rm -v "$(pwd):/home/cc/ripgrep" ripgrep-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        ./envgym/envbench.sh
    "
    exit 0
fi

echo "=========================================="
echo "BurntSushi_ripgrep Environment Benchmark Test"
echo "=========================================="
echo ""

echo "1. Checking System Dependencies..."
echo "--------------------------------"
# Check system commands
check_command "rustc" "Rust Compiler"
check_command "cargo" "Cargo"
check_command "git" "Git"
check_command "curl" "cURL"
check_command "pkg-config" "pkg-config"
check_command "cmake" "CMake"
check_command "python3" "Python 3"
check_command "grep" "GNU grep"
check_command "bash" "Bash"
check_command "zsh" "Zsh"
check_command "fish" "Fish shell"

echo ""
echo "2. Checking Rust Toolchain..."
echo "-----------------------------"
check_rust_version
check_cargo_version

# Check Rust toolchain configuration
if [ -f "rust-toolchain.toml" ]; then
    print_status "PASS" "rust-toolchain.toml exists"
    
    # Check if toolchain version matches
    toolchain_version=$(grep "channel = " rust-toolchain.toml | sed 's/.*channel = "//' | sed 's/".*//')
    print_status "INFO" "Toolchain version in rust-toolchain.toml: $toolchain_version"
    
    if [ "$toolchain_version" = "1.72.0" ]; then
        print_status "PASS" "Toolchain version matches required 1.72.0"
    else
        print_status "FAIL" "Toolchain version mismatch (expected 1.72.0, found $toolchain_version)"
    fi
else
    print_status "WARN" "rust-toolchain.toml missing (using system default)"
fi

# Check Rust target
if rustup target list --installed | grep -q "x86_64-unknown-linux-gnu"; then
    print_status "PASS" "x86_64-unknown-linux-gnu target is installed"
else
    print_status "FAIL" "x86_64-unknown-linux-gnu target is not installed"
fi

# Check musl target
if rustup target list --installed | grep -q "x86_64-unknown-linux-musl"; then
    print_status "PASS" "x86_64-unknown-linux-musl target is installed"
else
    print_status "WARN" "x86_64-unknown-linux-musl target is not installed"
fi

echo ""
echo "3. Checking Search Tools..."
echo "---------------------------"
# Check various search tools for comparison
check_command "ag" "The Silver Searcher"
check_command "pt" "The Platinum Searcher"
check_command "sift" "Sift"
check_command "ugrep" "ugrep"
check_command "grep" "GNU grep"

echo ""
echo "4. Checking Project Structure..."
echo "-------------------------------"
# Check if we're in the right directory
if [ -f "Cargo.toml" ]; then
    print_status "PASS" "Cargo.toml found"
else
    print_status "FAIL" "Cargo.toml not found"
    exit 1
fi

# Check if we're in the ripgrep project
if grep -q "ripgrep" Cargo.toml 2>/dev/null; then
    print_status "PASS" "ripgrep project detected"
else
    print_status "FAIL" "Not a ripgrep project"
fi

# Check project structure
print_status "INFO" "Checking project structure..."

if [ -d "crates" ]; then
    print_status "PASS" "crates directory exists"
else
    print_status "FAIL" "crates directory missing"
fi

if [ -d "tests" ]; then
    print_status "PASS" "tests directory exists"
else
    print_status "FAIL" "tests directory missing"
fi

if [ -d "scripts" ]; then
    print_status "PASS" "scripts directory exists"
else
    print_status "FAIL" "scripts directory missing"
fi

if [ -d "ci" ]; then
    print_status "PASS" "ci directory exists"
else
    print_status "FAIL" "ci directory missing"
fi

if [ -d "benchsuite" ]; then
    print_status "PASS" "benchsuite directory exists"
else
    print_status "FAIL" "benchsuite directory missing"
fi

if [ -d "pkg" ]; then
    print_status "PASS" "pkg directory exists"
else
    print_status "FAIL" "pkg directory missing"
fi

echo ""
echo "5. Checking Crates Structure..."
echo "-------------------------------"
# Check crates structure
if [ -d "crates" ]; then
    if [ -d "crates/core" ]; then
        print_status "PASS" "crates/core directory exists"
    else
        print_status "FAIL" "crates/core directory missing"
    fi
    
    if [ -d "crates/grep" ]; then
        print_status "PASS" "crates/grep directory exists"
    else
        print_status "FAIL" "crates/grep directory missing"
    fi
    
    if [ -d "crates/ignore" ]; then
        print_status "PASS" "crates/ignore directory exists"
    else
        print_status "FAIL" "crates/ignore directory missing"
    fi
    
    if [ -d "crates/cli" ]; then
        print_status "PASS" "crates/cli directory exists"
    else
        print_status "FAIL" "crates/cli directory missing"
    fi
    
    if [ -d "crates/regex" ]; then
        print_status "PASS" "crates/regex directory exists"
    else
        print_status "FAIL" "crates/regex directory missing"
    fi
    
    if [ -d "crates/searcher" ]; then
        print_status "PASS" "crates/searcher directory exists"
    else
        print_status "FAIL" "crates/searcher directory missing"
    fi
    
    if [ -d "crates/printer" ]; then
        print_status "PASS" "crates/printer directory exists"
    else
        print_status "FAIL" "crates/printer directory missing"
    fi
    
    if [ -d "crates/matcher" ]; then
        print_status "PASS" "crates/matcher directory exists"
    else
        print_status "FAIL" "crates/matcher directory missing"
    fi
    
    if [ -d "crates/globset" ]; then
        print_status "PASS" "crates/globset directory exists"
    else
        print_status "FAIL" "crates/globset directory missing"
    fi
    
    if [ -d "crates/pcre2" ]; then
        print_status "PASS" "crates/pcre2 directory exists"
    else
        print_status "FAIL" "crates/pcre2 directory missing"
    fi
fi

echo ""
echo "6. Checking Tests Structure..."
echo "------------------------------"
# Check tests structure
if [ -d "tests" ]; then
    if [ -f "tests/tests.rs" ]; then
        print_status "PASS" "tests/tests.rs exists"
    else
        print_status "FAIL" "tests/tests.rs missing"
    fi
    
    if [ -f "tests/misc.rs" ]; then
        print_status "PASS" "tests/misc.rs exists"
    else
        print_status "FAIL" "tests/misc.rs missing"
    fi
    
    if [ -f "tests/regression.rs" ]; then
        print_status "PASS" "tests/regression.rs exists"
    else
        print_status "FAIL" "tests/regression.rs missing"
    fi
    
    if [ -f "tests/feature.rs" ]; then
        print_status "PASS" "tests/feature.rs exists"
    else
        print_status "FAIL" "tests/feature.rs missing"
    fi
    
    if [ -d "tests/data" ]; then
        print_status "PASS" "tests/data directory exists"
    else
        print_status "FAIL" "tests/data directory missing"
    fi
fi

echo ""
echo "7. Testing Cargo Build..."
echo "------------------------"
# Test cargo build
if cargo check --quiet 2>/dev/null; then
    print_status "PASS" "cargo check successful"
else
    print_status "FAIL" "cargo check failed"
fi

echo ""
echo "8. Testing Rust Dependencies..."
echo "-------------------------------"
# Check if Cargo.toml has required dependencies
if grep -q "anyhow" Cargo.toml 2>/dev/null; then
    print_status "PASS" "anyhow dependency found in Cargo.toml"
else
    print_status "FAIL" "anyhow dependency missing in Cargo.toml"
fi

if grep -q "bstr" Cargo.toml 2>/dev/null; then
    print_status "PASS" "bstr dependency found in Cargo.toml"
else
    print_status "FAIL" "bstr dependency missing in Cargo.toml"
fi

if grep -q "lexopt" Cargo.toml 2>/dev/null; then
    print_status "PASS" "lexopt dependency found in Cargo.toml"
else
    print_status "FAIL" "lexopt dependency missing in Cargo.toml"
fi

if grep -q "serde_json" Cargo.toml 2>/dev/null; then
    print_status "PASS" "serde_json dependency found in Cargo.toml"
else
    print_status "FAIL" "serde_json dependency missing in Cargo.toml"
fi

if grep -q "termcolor" Cargo.toml 2>/dev/null; then
    print_status "PASS" "termcolor dependency found in Cargo.toml"
else
    print_status "FAIL" "termcolor dependency missing in Cargo.toml"
fi

echo ""
echo "9. Testing Source Code Structure..."
echo "-----------------------------------"
# Check source code structure
if [ -d "crates/core" ]; then
    rust_files=$(find crates -name "*.rs" | wc -l)
    print_status "INFO" "Found $rust_files Rust files in crates directory"
    if [ "$rust_files" -gt 0 ]; then
        print_status "PASS" "Rust source files found"
    else
        print_status "FAIL" "No Rust source files found"
    fi
fi

# Check for main binary
if [ -f "crates/core/main.rs" ]; then
    print_status "PASS" "crates/core/main.rs exists"
else
    print_status "FAIL" "crates/core/main.rs missing"
fi

echo ""
echo "10. Testing Build Scripts..."
echo "----------------------------"
# Check build scripts
if [ -f "build.rs" ]; then
    print_status "PASS" "build.rs exists"
else
    print_status "FAIL" "build.rs missing"
fi

# Check if build.rs is valid
if rustc --crate-type lib --crate-name build_script_runner build.rs 2>/dev/null; then
    print_status "PASS" "build.rs syntax is valid"
else
    print_status "FAIL" "build.rs syntax is invalid"
fi

echo ""
echo "11. Testing Configuration Files..."
echo "----------------------------------"
# Check configuration files
if [ -f "rustfmt.toml" ]; then
    print_status "PASS" "rustfmt.toml exists"
else
    print_status "FAIL" "rustfmt.toml missing"
fi

if [ -d ".cargo" ]; then
    print_status "PASS" ".cargo directory exists"
else
    print_status "FAIL" ".cargo directory missing"
fi

if [ -f ".cargo/config.toml" ]; then
    print_status "PASS" ".cargo/config.toml exists"
else
    print_status "WARN" ".cargo/config.toml missing"
fi

echo ""
echo "12. Testing Documentation..."
echo "----------------------------"
# Check documentation
if [ -f "README.md" ]; then
    print_status "PASS" "README.md exists"
else
    print_status "FAIL" "README.md missing"
fi

if [ -f "GUIDE.md" ]; then
    print_status "PASS" "GUIDE.md exists"
else
    print_status "FAIL" "GUIDE.md missing"
fi

if [ -f "FAQ.md" ]; then
    print_status "PASS" "FAQ.md exists"
else
    print_status "FAIL" "FAQ.md missing"
fi

if [ -f "CHANGELOG.md" ]; then
    print_status "PASS" "CHANGELOG.md exists"
else
    print_status "FAIL" "CHANGELOG.md missing"
fi

# Check if documentation mentions ripgrep
if grep -q "ripgrep" README.md 2>/dev/null; then
    print_status "PASS" "README.md contains ripgrep references"
else
    print_status "WARN" "README.md missing ripgrep references"
fi

echo ""
echo "13. Testing Cargo.toml Configuration..."
echo "---------------------------------------"
# Check Cargo.toml configuration
if grep -q 'edition = "2021"' Cargo.toml 2>/dev/null; then
    print_status "PASS" "Rust 2021 edition is specified"
else
    print_status "FAIL" "Rust 2021 edition is not specified"
fi

if grep -q 'rust-version = "1.72"' Cargo.toml 2>/dev/null; then
    print_status "PASS" "Rust version 1.72 is specified"
else
    print_status "FAIL" "Rust version 1.72 is not specified"
fi

if grep -q 'name = "ripgrep"' Cargo.toml 2>/dev/null; then
    print_status "PASS" "Package name is correctly set"
else
    print_status "FAIL" "Package name is not correctly set"
fi

echo ""
echo "14. Testing System Libraries..."
echo "-------------------------------"
# Check for required system libraries
if pkg-config --exists libpcre2-8 2>/dev/null; then
    print_status "PASS" "PCRE2 development libraries are available"
else
    print_status "WARN" "PCRE2 development libraries are not available"
fi

if pkg-config --exists openssl 2>/dev/null; then
    print_status "PASS" "OpenSSL development libraries are available"
else
    print_status "FAIL" "OpenSSL development libraries are not available"
fi

echo ""
echo "15. Testing Basic Rust Functionality..."
echo "---------------------------------------"
# Test basic Rust functionality
if rustc --version >/dev/null 2>&1; then
    print_status "PASS" "Rust compiler basic functionality works"
else
    print_status "FAIL" "Rust compiler basic functionality failed"
fi

if cargo --version >/dev/null 2>&1; then
    print_status "PASS" "Cargo basic functionality works"
else
    print_status "FAIL" "Cargo basic functionality failed"
fi

echo ""
echo "16. Testing Cargo Features..."
echo "-----------------------------"
# Test cargo features
if cargo check --features pcre2 --quiet 2>/dev/null; then
    print_status "PASS" "PCRE2 feature compilation successful"
else
    print_status "WARN" "PCRE2 feature compilation failed"
fi

echo ""
echo "17. Testing Search Tool Functionality..."
echo "----------------------------------------"
# Test search tool functionality
if command -v grep >/dev/null 2>&1; then
    if echo "test" | grep -q "test" 2>/dev/null; then
        print_status "PASS" "GNU grep basic functionality works"
    else
        print_status "FAIL" "GNU grep basic functionality failed"
    fi
else
    print_status "FAIL" "GNU grep is not available"
fi

if command -v ag >/dev/null 2>&1; then
    print_status "PASS" "The Silver Searcher (ag) is available"
else
    print_status "WARN" "The Silver Searcher (ag) is not available"
fi

if command -v pt >/dev/null 2>&1; then
    print_status "PASS" "The Platinum Searcher (pt) is available"
else
    print_status "WARN" "The Platinum Searcher (pt) is not available"
fi

if command -v sift >/dev/null 2>&1; then
    print_status "PASS" "Sift is available"
else
    print_status "WARN" "Sift is not available"
fi

if command -v ugrep >/dev/null 2>&1; then
    print_status "PASS" "ugrep is available"
else
    print_status "WARN" "ugrep is not available"
fi

echo ""
echo "18. Testing Git Configuration..."
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
echo "19. Testing Locale Configuration..."
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
echo "20. Testing Shell Completions..."
echo "--------------------------------"
# Test shell completions
if [ -d "/usr/share/bash-completion/completions" ]; then
    print_status "PASS" "Bash completion directory exists"
else
    print_status "WARN" "Bash completion directory missing"
fi

if [ -d "/usr/share/zsh/vendor-completions" ]; then
    print_status "PASS" "Zsh completion directory exists"
else
    print_status "WARN" "Zsh completion directory missing"
fi

if [ -d "/usr/share/fish/vendor_completions.d" ]; then
    print_status "PASS" "Fish completion directory exists"
else
    print_status "WARN" "Fish completion directory missing"
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
echo "- System dependencies (Rust 1.72+, Cargo, Git, build tools)"
echo "- Rust toolchain and targets"
echo "- Search tools for comparison (grep, ag, pt, sift, ugrep)"
echo "- Project structure and crates"
echo "- Cargo build and dependencies"
echo "- Source code organization"
echo "- Build scripts and configuration"
echo "- Documentation"
echo "- System libraries (PCRE2, OpenSSL)"
echo "- Basic tool functionality"
echo "- Cargo features"
echo "- Shell completions"
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
    print_status "INFO" "All tests passed! Your ripgrep environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your ripgrep environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi

print_status "INFO" "You can now build and test ripgrep."
print_status "INFO" "Example: cargo build --release"
print_status "INFO" "Example: cargo test"
print_status "INFO" "Example: cargo run -- 'pattern'"

echo ""
print_status "INFO" "For more information, see README.md and GUIDE.md"
print_status "INFO" "For benchmarks and comparisons, see the README.md examples"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/ripgrep ripgrep-env-test /bin/bash" 