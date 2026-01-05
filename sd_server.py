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
        
        if not api_key:
             # Try environment variable
             api_key = os.environ.get("OPENAI_API_KEY")
        
        if not api_key:
             return jsonify({"success": False, "error": "No OpenAI API Key provided. Please enter it in the extension settings."}), 401

        start_time = datetime.now()
        
        # Generate raw image
        image = cloud_server.generate_image(prompt, api_key)
        
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