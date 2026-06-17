#!/bin/bash

# Alibaba FastJSON2 Environment Benchmark Test
# Tests the environment for FastJSON2 Java project development

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

# Function to check Java version
check_java_version() {
    if command -v java &> /dev/null; then
        local java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2)
        local java_major=$(echo "${java_version:-}" | cut -d'.' -f1)
        if [ "${java_major:-}" = "1" ]; then
            java_major=$(echo "${java_version:-}" | cut -d'.' -f2)
        fi
        if [ -n "${java_major:-}" ] && [ "${java_major:-}" -ge 8 ]; then
            print_status "PASS" "Java version >= 8 (${java_version:-})"
        else
            print_status "WARN" "Java version should be >= 8 (${java_version:-})"
        fi
    else
        print_status "FAIL" "Java not found"
    fi
}

# Function to check Maven version
check_maven_version() {
    if command -v mvn &> /dev/null; then
        local maven_version=$(mvn -version 2>&1 | grep "Apache Maven" | head -1 | awk '{print $3}')
        local maven_major=$(echo "${maven_version:-}" | cut -d'.' -f1)
        local maven_minor=$(echo "${maven_version:-}" | cut -d'.' -f2)
        if [ -n "${maven_major:-}" ] && [ "${maven_major:-}" -ge 3 ] && [ "${maven_minor:-}" -ge 6 ]; then
            print_status "PASS" "Maven version >= 3.6 (${maven_version:-})"
        else
            print_status "WARN" "Maven version should be >= 3.6 (${maven_version:-})"
        fi
    else
        print_status "FAIL" "Maven not found"
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
        write_results_to_json
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "envgym/envgym.dockerfile" ]; then
        echo "ERROR: envgym.dockerfile not found. Please run this script from the alibaba_fastjson2 project root directory."
        write_results_to_json
        exit 1
    fi
    
    # Build Docker image
    echo "Building Docker image..."
    if ! docker build -f envgym/envgym.dockerfile -t fastjson2-env-test .; then
        echo -e "${RED}[CRITICAL ERROR]${NC} Docker build failed"
        echo -e "${RED}[RESULT]${NC} Benchmark score: 0 (Docker build failed)"
        write_results_to_json
        exit 1
    fi
    
    # Run this script inside Docker container
    echo "Running environment test in Docker container..."
    docker run --rm -v "$(pwd):/home/cc/EnvGym/data/alibaba_fastjson2" fastjson2-env-test bash -c "
        # Set up signal handling in container
        trap 'echo -e \"\n\033[0;31m[ERROR] Container interrupted\033[0m\"; exit 1' INT TERM
        ./envgym/envbench.sh
    "
    exit 0
fi

echo "=========================================="
echo "Alibaba FastJSON2 Environment Benchmark Test"
echo "=========================================="

echo "1. Checking System Dependencies..."
echo "--------------------------------"
check_command "java" "Java"
check_command "javac" "Java Compiler"
check_command "mvn" "Maven"
check_command "git" "Git"
check_command "bash" "Bash"
check_command "curl" "curl"
check_command "wget" "wget"

# Java version check
check_java_version

# Maven version check
check_maven_version

echo ""
echo "2. Checking Project Structure..."
echo "-------------------------------"
[ -f "pom.xml" ] && print_status "PASS" "pom.xml exists" || print_status "FAIL" "pom.xml missing"
[ -f "mvnw" ] && print_status "PASS" "mvnw exists" || print_status "FAIL" "mvnw missing"
[ -f "README.md" ] && print_status "PASS" "README.md exists" || print_status "FAIL" "README.md missing"
[ -f "README_EN.md" ] && print_status "PASS" "README_EN.md exists" || print_status "FAIL" "README_EN.md missing"
[ -f "LICENSE" ] && print_status "PASS" "LICENSE exists" || print_status "FAIL" "LICENSE missing"

# Check if we're in the FastJSON2 project
if [ -f "pom.xml" ] && grep -q "fastjson2" pom.xml 2>/dev/null; then
    print_status "PASS" "FastJSON2 project detected"
else
    print_status "FAIL" "Not a FastJSON2 project"
fi

# Check project modules
print_status "INFO" "Checking project modules..."
[ -d "core" ] && print_status "PASS" "core module exists" || print_status "FAIL" "core module missing"
[ -d "extension" ] && print_status "PASS" "extension module exists" || print_status "FAIL" "extension module missing"
[ -d "kotlin" ] && print_status "PASS" "kotlin module exists" || print_status "FAIL" "kotlin module missing"
[ -d "fastjson1-compatible" ] && print_status "PASS" "fastjson1-compatible module exists" || print_status "FAIL" "fastjson1-compatible module missing"
[ -d "benchmark" ] && print_status "PASS" "benchmark module exists" || print_status "WARN" "benchmark module missing"
[ -d "example-spring-test" ] && print_status "PASS" "example-spring-test exists" || print_status "WARN" "example-spring-test missing"
[ -d "example-solon-test" ] && print_status "PASS" "example-solon-test exists" || print_status "WARN" "example-solon-test missing"
[ -d "example-spring6-test" ] && print_status "PASS" "example-spring6-test exists" || print_status "WARN" "example-spring6-test missing"

echo ""
echo "3. Checking Environment Variables..."
echo "-----------------------------------"
# Check Java environment
if [ -n "${JAVA_HOME:-}" ]; then
    print_status "PASS" "JAVA_HOME is set: $JAVA_HOME"
else
    print_status "WARN" "JAVA_HOME is not set"
fi

# Check Maven environment
if [ -n "${MAVEN_HOME:-}" ]; then
    print_status "PASS" "MAVEN_HOME is set: $MAVEN_HOME"
else
    print_status "WARN" "MAVEN_HOME is not set"
fi

echo ""
echo "4. Testing Maven Build System..."
echo "--------------------------------"
# Test Maven wrapper
if [ -f "mvnw" ]; then
    if chmod +x mvnw 2>/dev/null; then
        print_status "PASS" "mvnw is executable"
    else
        print_status "WARN" "mvnw is not executable"
    fi
fi

# Test Maven commands
if command -v mvn &> /dev/null || [ -f "mvnw" ]; then
    if [ -f "mvnw" ]; then
        mvn_cmd="./mvnw"
    else
        mvn_cmd="mvn"
    fi
    
    # Test Maven help
    if timeout 30s $mvn_cmd help >/dev/null 2>&1; then
        print_status "PASS" "Maven help command works"
    else
        print_status "WARN" "Maven help command failed"
    fi
    
    # Test Maven version
    if timeout 30s $mvn_cmd -version >/dev/null 2>&1; then
        print_status "PASS" "Maven version command works"
    else
        print_status "WARN" "Maven version command failed"
    fi
else
    print_status "FAIL" "Neither mvn nor mvnw found"
fi

echo ""
echo "5. Testing Maven Build Process..."
echo "--------------------------------"
# Test basic Maven build
if command -v mvn &> /dev/null || [ -f "mvnw" ]; then
    if [ -f "mvnw" ]; then
        mvn_cmd="./mvnw"
    else
        mvn_cmd="mvn"
    fi
    
    # Test Maven clean
    if timeout 60s $mvn_cmd clean -q >/dev/null 2>&1; then
        print_status "PASS" "Maven clean successful"
    else
        print_status "WARN" "Maven clean failed"
    fi
    
    # Test Maven compile
    if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
        print_status "PASS" "Maven compile successful"
    else
        print_status "WARN" "Maven compile failed"
    fi
    
    # Test Maven test-compile
    if timeout 120s $mvn_cmd test-compile -q >/dev/null 2>&1; then
        print_status "PASS" "Maven test-compile successful"
    else
        print_status "WARN" "Maven test-compile failed"
    fi
else
    print_status "FAIL" "Maven not available for build testing"
fi

echo ""
echo "6. Testing Core Module..."
echo "------------------------"
# Test core module compilation
if [ -d "core" ]; then
    cd core
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Core module compilation successful"
        else
            print_status "WARN" "Core module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for core module testing"
    fi
    cd ..
else
    print_status "FAIL" "Core module directory not found"
fi

echo ""
echo "7. Testing Java Compilation..."
echo "-----------------------------"
# Create a simple test Java file to verify compilation
cat > TestCompilation.java << 'EOF'
public class TestCompilation {
    public static void main(String[] args) {
        System.out.println("Java compilation test successful");
    }
}
EOF

if javac TestCompilation.java 2>/dev/null; then
    print_status "PASS" "Basic Java compilation successful"
    rm -f TestCompilation.class
else
    print_status "FAIL" "Basic Java compilation failed"
fi

# Clean up test file
rm -f TestCompilation.java

echo ""
echo "8. Testing FastJSON2 Basic Functionality..."
echo "------------------------------------------"
# Create a test Java file with FastJSON2 usage
cat > FastJSON2Test.java << 'EOF'
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.alibaba.fastjson2.JSONArray;

public class FastJSON2Test {
    public static void main(String[] args) {
        try {
            // Test JSON parsing
            String jsonStr = "{\"name\":\"test\",\"age\":25}";
            JSONObject obj = JSON.parseObject(jsonStr);
            System.out.println("JSON parsing successful: " + obj.getString("name"));
            
            // Test JSON serialization
            JSONObject testObj = new JSONObject();
            testObj.put("message", "Hello FastJSON2");
            String serialized = JSON.toJSONString(testObj);
            System.out.println("JSON serialization successful: " + serialized);
            
            // Test JSONArray
            JSONArray array = JSON.parseArray("[1,2,3,4,5]");
            System.out.println("JSONArray parsing successful: " + array.size() + " elements");
            
            System.out.println("FastJSON2 basic functionality test completed successfully");
        } catch (Exception e) {
            System.err.println("FastJSON2 test failed: " + e.getMessage());
            System.exit(1);
        }
    }
}
EOF

# Try to compile the FastJSON2 test (this will fail without dependencies, but we can check compilation)
if javac -cp "core/target/classes:core/target/test-classes" FastJSON2Test.java 2>/dev/null; then
    print_status "PASS" "FastJSON2 test compilation successful"
    rm -f FastJSON2Test.class
else
    print_status "WARN" "FastJSON2 test compilation failed (expected without dependencies)"
fi

# Clean up test file
rm -f FastJSON2Test.java

echo ""
echo "9. Testing Maven Dependencies..."
echo "-------------------------------"
# Test Maven dependencies resolution
if command -v mvn &> /dev/null || [ -f "mvnw" ]; then
    if [ -f "mvnw" ]; then
        mvn_cmd="./mvnw"
    else
        mvn_cmd="mvn"
    fi
    
    if timeout 120s $mvn_cmd dependency:resolve -q >/dev/null 2>&1; then
        print_status "PASS" "Maven dependencies resolved successfully"
    else
        print_status "WARN" "Maven dependencies resolution failed"
    fi
    
    if timeout 120s $mvn_cmd dependency:resolve -Dclassifier=tests -q >/dev/null 2>&1; then
        print_status "PASS" "Maven test dependencies resolved successfully"
    else
        print_status "WARN" "Maven test dependencies resolution failed"
    fi
else
    print_status "FAIL" "Maven not available for dependency testing"
fi

echo ""
echo "10. Testing Extension Modules..."
echo "--------------------------------"
# Test extension modules
if [ -d "extension" ]; then
    cd extension
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Extension module compilation successful"
        else
            print_status "WARN" "Extension module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for extension module testing"
    fi
    cd ..
else
    print_status "WARN" "Extension module not found"
fi

if [ -d "extension-spring5" ]; then
    cd extension-spring5
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Extension-spring5 module compilation successful"
        else
            print_status "WARN" "Extension-spring5 module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for extension-spring5 module testing"
    fi
    cd ..
else
    print_status "WARN" "Extension-spring5 module not found"
fi

if [ -d "extension-spring6" ]; then
    cd extension-spring6
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Extension-spring6 module compilation successful"
        else
            print_status "WARN" "Extension-spring6 module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for extension-spring6 module testing"
    fi
    cd ..
else
    print_status "WARN" "Extension-spring6 module not found"
fi

echo ""
echo "11. Testing Kotlin Module..."
echo "----------------------------"
# Test Kotlin module
if [ -d "kotlin" ]; then
    cd kotlin
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Kotlin module compilation successful"
        else
            print_status "WARN" "Kotlin module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for Kotlin module testing"
    fi
    cd ..
else
    print_status "WARN" "Kotlin module not found"
fi

echo ""
echo "12. Testing FastJSON1 Compatibility..."
echo "-------------------------------------"
# Test FastJSON1 compatibility module
if [ -d "fastjson1-compatible" ]; then
    cd fastjson1-compatible
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "FastJSON1-compatible module compilation successful"
        else
            print_status "WARN" "FastJSON1-compatible module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for FastJSON1-compatible module testing"
    fi
    cd ..
else
    print_status "WARN" "FastJSON1-compatible module not found"
fi

echo ""
echo "13. Testing Example Projects..."
echo "------------------------------"
# Test example projects
if [ -d "example-spring-test" ]; then
    cd example-spring-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "example-spring-test compilation successful"
        else
            print_status "WARN" "example-spring-test compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for example-spring-test testing"
    fi
    cd ..
else
    print_status "WARN" "example-spring-test not found"
fi

if [ -d "example-solon-test" ]; then
    cd example-solon-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "example-solon-test compilation successful"
        else
            print_status "WARN" "example-solon-test compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for example-solon-test testing"
    fi
    cd ..
else
    print_status "WARN" "example-solon-test not found"
fi

if [ -d "example-spring6-test" ]; then
    cd example-spring6-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "example-spring6-test compilation successful"
        else
            print_status "WARN" "example-spring6-test compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for example-spring6-test testing"
    fi
    cd ..
else
    print_status "WARN" "example-spring6-test not found"
fi

echo ""
echo "14. Testing Benchmark Module..."
echo "-------------------------------"
# Test benchmark module
if [ -d "benchmark" ]; then
    cd benchmark
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Benchmark module compilation successful"
        else
            print_status "WARN" "Benchmark module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for benchmark module testing"
    fi
    cd ..
else
    print_status "WARN" "Benchmark module not found"
fi

echo ""
echo "15. Testing Safe Mode..."
echo "------------------------"
# Test safe mode module
if [ -d "safemode-test" ]; then
    cd safemode-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Safe mode test module compilation successful"
        else
            print_status "WARN" "Safe mode test module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for safe mode test module testing"
    fi
    cd ..
else
    print_status "WARN" "Safe mode test module not found"
fi

echo ""
echo "16. Testing Code Generation..."
echo "------------------------------"
# Test code generation modules
if [ -d "codegen" ]; then
    cd codegen
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Code generation module compilation successful"
        else
            print_status "WARN" "Code generation module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for code generation module testing"
    fi
    cd ..
else
    print_status "WARN" "Code generation module not found"
fi

if [ -d "codegen-test" ]; then
    cd codegen-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Code generation test module compilation successful"
        else
            print_status "WARN" "Code generation test module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for code generation test module testing"
    fi
    cd ..
else
    print_status "WARN" "Code generation test module not found"
fi

echo ""
echo "17. Testing Android Support..."
echo "------------------------------"
# Test Android module
if [ -d "android-test" ]; then
    cd android-test
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "Android test module compilation successful"
        else
            print_status "WARN" "Android test module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for Android test module testing"
    fi
    cd ..
else
    print_status "WARN" "Android test module not found"
fi

echo ""
echo "18. Testing GraalVM Native Support..."
echo "-------------------------------------"
# Test GraalVM native example
if [ -d "example-graalvm-native" ]; then
    cd example-graalvm-native
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "GraalVM native example compilation successful"
        else
            print_status "WARN" "GraalVM native example compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for GraalVM native example testing"
    fi
    cd ..
else
    print_status "WARN" "GraalVM native example not found"
fi

echo ""
echo "19. Testing JDK 17 Support..."
echo "------------------------------"
# Test JDK 17 module
if [ -d "test-jdk17" ]; then
    cd test-jdk17
    if command -v mvn &> /dev/null || [ -f "../mvnw" ]; then
        if [ -f "../mvnw" ]; then
            mvn_cmd="../mvnw"
        else
            mvn_cmd="mvn"
        fi
        
        if timeout 120s $mvn_cmd compile -q >/dev/null 2>&1; then
            print_status "PASS" "JDK 17 test module compilation successful"
        else
            print_status "WARN" "JDK 17 test module compilation failed"
        fi
    else
        print_status "WARN" "Maven not available for JDK 17 test module testing"
    fi
    cd ..
else
    print_status "WARN" "JDK 17 test module not found"
fi

echo ""
echo "20. Testing Maven Install..."
echo "----------------------------"
# Test Maven install (this will take longer)
if command -v mvn &> /dev/null || [ -f "mvnw" ]; then
    if [ -f "mvnw" ]; then
        mvn_cmd="./mvnw"
    else
        mvn_cmd="mvn"
    fi
    
    if timeout 300s $mvn_cmd install -DskipTests -q >/dev/null 2>&1; then
        print_status "PASS" "Maven install successful"
    else
        print_status "WARN" "Maven install failed or timed out"
    fi
else
    print_status "FAIL" "Maven not available for install testing"
fi

echo ""
echo "=========================================="
echo "Environment Benchmark Test Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "--------"
echo "This script has tested:"
echo "- System dependencies (Java, Maven, Git, bash, curl, wget)"
echo "- Java version compatibility (>= 8)"
echo "- Maven version compatibility (>= 3.6)"
echo "- Project structure and modules"
echo "- Environment variables (JAVA_HOME, MAVEN_HOME)"
echo "- Maven build system (mvnw, help, version, clean, compile, test-compile)"
echo "- Core FastJSON2 functionality"
echo "- Maven dependencies resolution"
echo "- All extension modules (extension, extension-spring5, extension-spring6)"
echo "- Kotlin support"
echo "- FastJSON1 compatibility"
echo "- Example projects (spring-test, solon-test, spring6-test)"
echo "- Benchmark module"
echo "- Safe mode testing"
echo "- Code generation"
echo "- Android support"
echo "- GraalVM native support"
echo "- JDK 17 support"
echo "- Complete Maven install"
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
    print_status "INFO" "All tests passed! Your FastJSON2 environment is ready!"
elif [ $FINAL_FAIL_COUNT -lt 5 ]; then
    print_status "INFO" "Most tests passed! Your FastJSON2 environment is mostly ready."
    print_status "WARN" "Some optional dependencies are missing, but core functionality should work."
else
    print_status "WARN" "Many tests failed. Please check the output above."
    print_status "INFO" "This might indicate that the environment is not properly set up."
fi
echo ""
print_status "INFO" "You can now build and run FastJSON2 projects."
print_status "INFO" "Example: mvn clean install"
echo ""
print_status "INFO" "For more information, see README.md and README_EN.md"

print_status "INFO" "To start interactive container: docker run -it --rm -v \$(pwd):/home/cc/EnvGym/data/alibaba_fastjson2 fastjson2-env-test /bin/bash" 