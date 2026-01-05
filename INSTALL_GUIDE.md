# PixelAI Installation Guide

## 1. Setup the Server (Python)
This tool requires a small background script to talk to the AI services.

### Prerequisites
- **Python 3.10+** installed.

### Steps
1.  **Open Terminal** in this folder.
2.  **Rename Config**:
    - Rename `.env.example` to `.env`.
    - Open it and paste your API key (get one from [OpenAI](https://platform.openai.com) or [Stability AI](https://platform.stability.ai)).
    ```bash
    OPENAI_API_KEY=sk-...
    STABILITY_API_KEY=sk-...
    ```
3.  **Run Server**:
    - **Mac/Linux:** Run `./start_server.sh`
    - **Windows:** Run `start_server.bat` (if available, otherwise `python sd_server.py`)
    - *The script will automatically install dependencies (flask, pillow, etc) on first run.*

---

## 2. Install the Extension (Aseprite)
1.  Double-click `pixel-ai-tool.aseprite-extension`.
2.  Aseprite will open and ask to install. Click **Install**.
3.  Restart Aseprite.

---

## 3. Usage
1.  Ensure the server is running (you should see "Running on http://127.0.0.1:5000").
2.  In Aseprite, go to `File` -> `Scripts` -> `Local AI Generator`.
3.  **For DALL-E 3:**
    - Select "OpenAI". Enter prompt. Click Generate.
4.  **For Hex Prison (Shape Control):**
    - Draw a shape (e.g. white hex on transparency).
    - Select "Stability AI".
    - Check "Use Active Layer Shape".
    - Set Strength to ~0.7.
    - Click Generate.
