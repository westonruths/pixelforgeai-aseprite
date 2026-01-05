#!/bin/bash

# Local AI Generator for Aseprite - macOS Setup Script
# =====================================================

echo ""
echo "========================================================"
echo "   Local AI Generator for Aseprite - macOS Setup"
echo "========================================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Current directory: $SCRIPT_DIR"

# Check if required files exist
echo "[1/4] Checking required files..."
if [ ! -f "startup_script.py" ]; then
    echo "✗ startup_script.py not found in current directory"
    echo "Please ensure all files are in the same folder"
    exit 1
fi

if [ ! -f "sd_server.py" ]; then
    echo "✗ sd_server.py not found"
    exit 1
else
    echo "✓ sd_server.py found"
fi

# Find a compatible Python version (3.12 or earlier, as PyTorch doesn't support 3.13 yet)
echo "[2/4] Checking Python installation..."

# Try to find Python 3.12 first, then fall back to 3.11, 3.10
PYTHON_CMD=""
for version in python3.12 python3.11 python3.10; do
    if command -v $version &> /dev/null; then
        PYTHON_CMD=$version
        break
    fi
done

# Check Homebrew locations as fallback
if [ -z "$PYTHON_CMD" ]; then
    for version in /usr/local/bin/python3.12 /usr/local/bin/python3.11 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11; do
        if [ -x "$version" ]; then
            PYTHON_CMD=$version
            break
        fi
    done
fi

if [ -z "$PYTHON_CMD" ]; then
    echo "✗ Python 3.10-3.12 not found."
    echo ""
    echo "PyTorch requires Python 3.10-3.12 (3.13 is not yet supported)"
    echo "Please install Python 3.12:"
    echo "  brew install python@3.12"
    echo ""
    exit 1
fi

echo "✓ Using $PYTHON_CMD"
$PYTHON_CMD --version

# Create virtual environment
echo "[3/4] Setting up virtual environment..."
if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
    # Check if existing venv uses a compatible Python
    VENV_PYTHON_VERSION=$(./venv/bin/python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    if [[ "$VENV_PYTHON_VERSION" == "3.13" ]]; then
        echo "⚠ Existing venv uses Python 3.13, recreating with Python 3.12..."
        rm -rf venv
        $PYTHON_CMD -m venv venv
        echo "✓ Virtual environment recreated with compatible Python"
    else
        echo "✓ Virtual environment already exists (Python $VENV_PYTHON_VERSION)"
    fi
else
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
    if [ $? -ne 0 ]; then
        echo "✗ Failed to create virtual environment"
        exit 1
    fi
    echo "✓ Virtual environment created"
fi

# Create necessary directories
echo "[4/4] Setting up directories..."
mkdir -p loras models
echo "✓ Directories created"

# Check for API Key
if [ ! -f ".env" ]; then
    echo ""
    echo "========================================================"
    echo "                 OpenAI API Setup"
    echo "========================================================"
    echo "To avoid entering your API Key every time, please enter it now."
    echo "(It will be saved to a .env file securely)"
    echo ""
    read -p "Enter OpenAI API Key (or press Enter to skip): " API_KEY
    
    if [ ! -z "$API_KEY" ]; then
        echo "OPENAI_API_KEY=$API_KEY" > .env
        echo "✓ API Key saved to .env"
    else
        echo "⚠ No API Key saved. You will need to enter it in the extension."
    fi
else
    echo "✓ API Key found in .env"
fi

echo ""
echo "========================================================"
echo "              Basic Setup Complete!"
echo "========================================================"
echo ""
echo "Now starting Python setup and server..."
echo "Python will handle dependency installation and server startup."
echo ""

# Activate virtual environment and start Python setup
source venv/bin/activate
if [ $? -ne 0 ]; then
    echo "✗ Failed to activate virtual environment"
    exit 1
fi

# Load API Key if exists
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✓ Loaded API Key from .env"
fi

echo "✓ Virtual environment activated"
echo "Starting Python setup script..."
echo ""

# Let Python handle everything from here
python startup_script.py

# If we get here, the server has stopped
echo ""
echo "========================================================"
echo "                   SETUP/SERVER ENDED"
echo "========================================================"
echo ""
