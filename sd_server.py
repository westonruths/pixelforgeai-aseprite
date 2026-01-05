#!/usr/bin/env python3
"""
Local AI Generator Server for Aseprite (Cloud Edition)
Uses OpenAI DALL-E 3 for generation instead of local GPU.
"""
import os
import sys
import json
import base64
import io
import requests
import warnings
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
import numpy as np
from openai import OpenAI

# Suppress minor warnings
warnings.filterwarnings("ignore")

import logging
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)
CORS(app)

class CloudArtServer:
    def __init__(self):
        print(f"🚀 Cloud AI Generator Server (OpenAI DALL-E 3)")
        
    def image_to_base64(self, image):
        """Convert PIL image to base64 encoded bytes."""
        if image.mode != 'RGBA':
            image = image.convert('RGBA')
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        return base64.b64encode(buffer.getvalue()).decode()

    def generate_image(self, prompt, api_key, **kwargs):
        """Generate image using OpenAI DALL-E 3."""
        print(f"🎨 Generating with DALL-E 3: '{prompt[:50]}...'")
        
        try:
            client = OpenAI(api_key=api_key)
            
            # Enhancing prompt for pixel art
            enhanced_prompt = f"Pixel art style, {prompt}"
            if "pixel art" not in prompt.lower():
                enhanced_prompt += ", authentic retro game sprite, clean pixel art, flat colors"
                
            response = client.images.generate(
                model="dall-e-3",
                prompt=enhanced_prompt,
                size="1024x1024",
                quality="standard",
                n=1,
            )
            
            image_url = response.data[0].url
            print(f"✅ Image URL received: {image_url[:50]}...")
            
            # Download image
            img_data = requests.get(image_url).content
            image = Image.open(io.BytesIO(img_data))
            
            return image
            
        except Exception as e:
            raise Exception(f"OpenAI API Error: {str(e)}")
    def generate_image_stability(self, prompt, api_key, init_image=None, strength=0.35, **kwargs):
        """Generate image using Stability AI Structure Control (V2)."""
        print(f"🎨 Generating with Stability AI (Structure Control)...")
        
        # New V2 Endpoint for Structure Control
        # This preserves the "Structure" (Shape/Edges) of the input but generates new content.
        api_host = os.getenv('API_HOST', 'https://api.stability.ai')
        url = f"{api_host}/v2beta/stable-image/control/structure"

        # 1. Flatten Transparency (Composite on Black) to ensure clear structure
        if init_image:
            if init_image.mode == 'RGBA':
                background = Image.new('RGB', init_image.size, (0, 0, 0))
                background.paste(init_image, mask=init_image.split()[3])
                init_image = background
            else:
                init_image = init_image.convert('RGB')
                
            # Resize logic (V2 supports various sizes, but sticking to 1024 safe zone)
            if init_image.size != (1024, 1024):
                print(f"   - Upscaling guide image from {init_image.size} to (1024, 1024)")
                init_image = init_image.resize((1024, 1024), Image.NEAREST)

        # Convert to bytes
        img_byte_arr = io.BytesIO()
        init_image.save(img_byte_arr, format='PNG')
        img_byte_arr = img_byte_arr.getvalue()

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json"
        }
        
        # Multipart Data for V2 Structure
        # image: The guide image
        # prompt: The prompt
        # control_strength: 0.0 to 1.0 (How much structure to keep)
        files = {
            "image": ("struct_guide.png", img_byte_arr, "image/png"),
        }
        
        # Map strength: 
        # User Strength 1.0 = "Change Everything" -> Control Strength 0.0
        # User Strength 0.0 = "Keep Everything" -> Control Strength 1.0
        # Use simple inversion + bias to ensure structure is respected.
        # 0.35 gen strength -> 0.65+0.2 = 0.85 Control
        # 1.0 gen strength -> 0.0+0.2 = 0.2 Control
        control_strength = max(0.1, min(1.0, 1.0 - strength + 0.3)) 
        
        data = {
            "prompt": prompt,
            "negative_prompt": "blurry, low quality, bad anatomy, bad perspective",
            "control_strength": str(control_strength),
            "seed": "0",
            "output_format": "png"
        }
        
        print(f"   - Sending to V2 Structure. Control Strength: {control_strength:.2f}")

        response = requests.post(url, headers=headers, files=files, data=data)

        if response.status_code != 200:
            raise Exception(f"Stability V2 Error ({response.status_code}): {response.text}")

        # V2 Response format: { "image": "base64...", "finish_reason": "SUCCESS", "seed": ... }
        data = response.json()
        image_b64 = data["image"]
        image = Image.open(io.BytesIO(base64.b64decode(image_b64)))
        return image
    def process_for_pixel_art(self, image, target_size=(64, 64), colors=16):
        """Post-processing to make high-res DALL-E output look like pixel art."""
        print(f"🖼️ Downscaling to pixel art: {target_size}, {colors} colors")
        
        # 1. Resize to target (Nearest Neighbor is key for pixel look)
        image = image.resize(target_size, Image.NEAREST)
        
        # 2. Color Quantization
        if colors > 0:
            if image.mode == 'RGBA':
                alpha = image.getchannel('A')
                rgb_image = image.convert('RGB').quantize(
                    colors=int(colors), 
                    method=Image.MEDIANCUT
                )
                image = rgb_image.convert('RGBA')
                # Restore alpha? DALL-E doesn't do transparency usually.
                # So we might want to keep it solid or try to key out background.
                # For now, solid is safer unless user asked for removal.
            else:
                image = image.quantize(colors=int(colors), method=Image.MEDIANCUT).convert('RGB')
        
        print("✅ Pixel art processing complete")
        return image

# Initialize server
cloud_server = CloudArtServer()

@app.route('/generate', methods=['POST'])
def generate():
    try:
        data = request.get_json()
        prompt = data.get('prompt')
        api_key = data.get('api_key')
        
        if not prompt:
            return jsonify({"success": False, "error": "No prompt provided"}), 400
        
        # Determine Provider
        ai_provider = data.get('ai_provider', 'OpenAI (DALL-E)')
        print(f"🤖 Provider: {ai_provider}")
        
        if 'Stability' in ai_provider:
             api_key = data.get('api_key') or os.environ.get("STABILITY_API_KEY")
             if not api_key:
                  return jsonify({"success": False, "error": "No Stability API Key found in .env"}), 401
        else:
             api_key = data.get('api_key') or os.environ.get("OPENAI_API_KEY")
             if not api_key:
                  return jsonify({"success": False, "error": "No OpenAI API Key found in .env"}), 401

        start_time = datetime.now()
        
        # Handle Init Image (Guide)
        init_image = None
        init_image_b64 = data.get('init_image')
        if init_image_b64:
            try:
                # Decode init image
                init_image = Image.open(io.BytesIO(base64.b64decode(init_image_b64)))
                
                # DEBUG: Save copy of what we received
                try:
                    debug_path = "debug_received_guide.png"
                    init_image.save(debug_path)
                    print(f"💾 Debug: Saved received guide image to '{debug_path}'")
                except Exception as e:
                    print(f"⚠️ Failed to save debug image: {e}")

                if init_image.mode != "RGBA":
                    init_image = init_image.convert("RGBA")
            except Exception as e:
                print(f"⚠️ Failed to process init_image: {e}")

        # GENERATE
        if 'Stability' in ai_provider:
            strength = float(data.get('strength', 0.35))
            image = cloud_server.generate_image_stability(prompt, api_key, init_image=init_image, strength=strength)
        else:
            image = cloud_server.generate_image(prompt, api_key)

        # DEBUG: Save raw output from AI
        try:
            image.save("debug_raw_output.png")
            print(f"💾 Debug: Saved raw AI output to 'debug_raw_output.png'")
        except Exception as e:
            print(f"⚠️ Failed to save debug raw output: {e}")
        
        # Process for pixel art
        pixel_width = int(data.get('pixel_width', 64))
        pixel_height = int(data.get('pixel_height', 64))
        colors = int(data.get('colors', 16))
        
        pixel_image = cloud_server.process_for_pixel_art(
            image,
            target_size=(pixel_width, pixel_height),
            colors=colors
        )
        
        img_base64 = cloud_server.image_to_base64(pixel_image)
        
        generation_time = (datetime.now() - start_time).total_seconds()
        print(f"⏱️ Total time: {generation_time:.2f}s")
        
        return jsonify({
            "success": True,
            "image": {
                "base64": img_base64,
                "width": pixel_width,
                "height": pixel_height,
                "mode": "rgba"
            },
            "generation_time": generation_time
        })
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "mode": "cloud",
        "service": "openai"
    })

# Stubs for compatibility with existing extension
@app.route('/models', methods=['GET'])
def list_models():
    return jsonify({"models": ["dall-e-3"]})

@app.route('/loras', methods=['GET'])
def list_loras():
    return jsonify({"loras": ["None"]})

if __name__ == "__main__":
    print("\nStarting Cloud AI Server...")
    app.run(host='127.0.0.1', port=5000, debug=False)