#!/usr/bin/env python3
"""
Startup Script for PixelAI (Cloud Edition)
"""
import os
import sys
import subprocess
import venv
import shutil

# Configuration
VENV_DIR = "venv"
REQUIREMENTS_FILE = "requirements.txt"
SERVER_SCRIPT = "sd_server.py"

def check_python_version():
    """Ensure we are running a compatible Python version."""
    major, minor = sys.version_info[:2]
    print(f"✅ Python {major}.{minor} detected")
    return True

def create_venv():
    """Create a virtual environment if it doesn't exist."""
    if not os.path.exists(VENV_DIR):
        print(f"📦 Creating virtual environment in {VENV_DIR}...")
        venv.create(VENV_DIR, with_pip=True)
    else:
        print(f"✅ Virtual environment found in {VENV_DIR}")

def install_dependencies():
    """Install dependencies from requirements.txt."""
    print("🔧 Installing/Updating dependencies...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", REQUIREMENTS_FILE])
        print("✅ Dependencies installed.")
    except subprocess.CalledProcessError:
        print("❌ Failed to install dependencies.")
        sys.exit(1)

def start_server():
    """Start the Python server."""
    print("\n🚀 Starting PixelAI Cloud Server...")
    python_cmd = os.path.join(VENV_DIR, "bin", "python")
    
    try:
        # Replace current process with server process
        os.execv(python_cmd, [python_cmd, SERVER_SCRIPT])
    except Exception as e:
        print(f"❌ Failed to start server: {e}")
        sys.exit(1)

def main():
    print("========================================")
    print("   PixelAI Cloud Server Setup")
    print("========================================")
    
    check_python_version()
    create_venv()
    install_dependencies()
    start_server()

if __name__ == "__main__":
    main()