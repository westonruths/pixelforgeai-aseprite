# PixelAI Cloud Edition for macOS

## 🚀 How to Run

1.  **Open Terminal**
2.  Navigate to the folder:
    ```bash
    cd /Users/wruths/Downloads/TheFiles
    ```
3.  **Start the Server:**
    ```bash
    ./start_server.sh
    ```
    *(Ideally, keep this window open while using Aseprite)*

## ☁️ Setup in Aseprite

1.  **Install Extension**:
    - Open Aseprite -> `Edit` -> `Preferences` -> `Extensions`.
    - **Uninstall** any old PixelAI extensions.
    - Click `Add Extension` and select:
      **`PixelAI_Cloud.aseprite-extension`**
    - Restart Aseprite.

2.  **Add API Key**:
    - Open the plugin (`File` -> `Scripts` -> `Local AI Generator`).
    - Enter your **OpenAI API Key** in the box.
    - Click Generate!

## ⚠️ "Address already in use" Error?

If you see this error, **AirPlay Receiver** is blocking port 5000.
1.  Go to **System Settings** -> Search "AirPlay Receiver".
2.  Turn it **OFF**.
3.  Run `./start_server.sh` again.

## ✨ Features
-   Instant generation (DALL-E 3).
-   Automatic pixel art conversion.
-   No heavy downloads (saved ~15GB).
