# PixelForgeAI – Installation Guide

## Prerequisites

- **Python 3.10+** (check with `python3 --version`)
- An API key from [OpenAI](https://platform.openai.com/api-keys) or [Stability AI](https://platform.stability.ai/account/keys)

---

## Step 1: Configure the Server

1.  **Copy the example config:**
    ```bash
    cp .env.example .env
    ```

2.  **Edit `.env`** and paste your API key(s):
    ```
    OPENAI_API_KEY=sk-proj-...
    STABILITY_API_KEY=sk-...
    ```

3.  **Start the server:**
    - **Mac/Linux:** `./start_server.sh`
    - **Windows:** `python sd_server.py`
    
    > The script auto-installs dependencies on first run.

---

## Step 2: Install the Extension

1.  Double-click **`PixelForgeAI.aseprite-extension`** (or open it with Aseprite).
2.  Aseprite will prompt you to install. Click **Install**.
3.  Restart Aseprite.

---

## Step 3: Generate Art

1.  Ensure the server is running (terminal shows `Running on http://127.0.0.1:5000`).
2.  In Aseprite: `File` → `PixelForgeAI`.

### DALL-E 3 (Text-to-Image)
- Select **OpenAI** as provider.
- Enter a prompt and click **Generate**.

### Stability AI (Shape Control)
- Draw a shape on a layer (e.g., a white hexagon).
- Select **Stability AI** as provider.
- Check **"Use Active Layer Shape"**.
- Set **Strength** to ~0.65–0.75.
- Click **Generate**.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No API Key" error | Ensure `.env` exists and contains your key. Restart server. |
| Server won't start | Check Python version (`python3 --version`). Must be 3.10–3.12. |
| Extension not showing | Restart Aseprite after installing extension. |
