# PixelAI: Cloud-Powered Aseprite Tools

**Professional AI generation directly within Aseprite**, powered by DALL-E 3 and Stability AI. 

> **Note:** This is a "Cloud Edition" tool. It requires an API Key (OpenAI or Stability AI) but runs lightly on any computer (Mac/Windows/Linux) without needing a powerful GPU.

## Features
- 🎨 **Text-to-Pixel Art:** Generate high-quality assets using DALL-E 3.
- 🧱 **Hex Prison Workflow (Stability AI):** Use your own shapes as strict guides. The AI paints *inside* your shape, preserving your exact geometry.
- 🖼️ **Seamless Integration:** Generated images appear directly as new layers/frames in Aseprite.
- 🛠️ **No Local GPU Needed:** All heavy lifting is done in the cloud.

## Installation Breakdown
1. **Install Extension:** Double-click `pixel-ai-tool.aseprite-extension` to install it in Aseprite.
2. **Start Server:** Run the lightweight Python bridge (`start_server.sh` or `start_server.bat`).
   - *Why a server?* Aseprite's scripting language (Lua) cannot easily handle complex secure API calls and image processing. The python script handles the heavy lifting.

## Quick Start
1.  Add your API Key to `.env`.
2.  Run `./start_server.sh`.
3.  Open Aseprite -> `File` -> `Scripts` -> `PixelAI`.

Read [INSTALL_GUIDE.md](INSTALL_GUIDE.md) for detailed setup instructions.

## License
MIT License. Free to use and modify.
