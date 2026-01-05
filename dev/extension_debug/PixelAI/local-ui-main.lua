-- Local AI Generator for Aseprite - Enhanced UI Version
-- Professional pixel art generation using Stable Diffusion
-- Version 2.0 - Ready for Publishing

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*)[/\\]")

local function safe_dofile(filename)
    local full_path = script_dir .. "/" .. filename
    local success, result = pcall(dofile, full_path)
    if not success then 
        app.alert("Error loading " .. filename .. ": " .. tostring(result))
        return nil
    end
    return result
end

-- Load required libraries
local json = safe_dofile("json.lua")
local base64 = safe_dofile("base64.lua") 
local http_client = safe_dofile("http-client.lua")

if not json or not base64 or not http_client then 
    app.alert("Failed to load required libraries. Please ensure all files are in the same directory.")
    return 
end

-- Plugin configuration
local plugin_config = {
    server_url = "http://127.0.0.1:5000",
    name = "Local AI Generator v6.3",
    version = "6.3.0"
}

-- Global state
local is_generating = false
local current_dialog = nil
local available_models = {}
local available_loras = {}
-- local server_status = "Unknown" -- Removed
local last_generation_time = 0

-- Enhanced default settings with better defaults for pixel art
local default_settings = {
    base_prompt = "pixel art, 16-bit style, vibrant colors",
    prompt = "cute character",
    pixel_width = 64,
    pixel_height = 64,
    colors = 16,
    remove_background = false,
    output_method = "New Layer",
    api_key = "",  -- Added API Key
    ai_provider = "OpenAI (DALL-E)",
    use_guide_image = false,
    strength = 0.35
}

-- Current settings (copy of defaults)
local current_settings = {}
for k, v in pairs(default_settings) do 
    current_settings[k] = v 
end

-- Settings persistence
local settings_file = script_dir .. "/settings.json"

local function save_settings()
    local file = io.open(settings_file, "w")
    if file then
        file:write(json.encode(current_settings))
        file:close()
    end
end

local function load_settings()
    local file = io.open(settings_file, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local success, saved = pcall(json.decode, content)
        if success and saved then
            -- Merge saved into current
            for k, v in pairs(saved) do
                current_settings[k] = v
            end
        end
    end
end

-- Initialize settings
load_settings()

-- Preset prompts for quick access
local preset_prompts = {
    "pixel art, cute animal, simple design, flat colors",
    "pixel art, fantasy character, rpg style, detailed sprite",
    "pixel art, sci-fi robot, futuristic, metallic",
    "pixel art, magical item, glowing, mystical",
    "pixel art, food item, colorful, appetizing",
    "pixel art, vehicle, side view, detailed",
    "pixel art, building, isometric view, architectural",
    "pixel art, nature scene, trees, peaceful"
}

-- Quality presets for base generation resolution
local quality_presets = {
    {name = "Fast (512x512)", width = 512, height = 512, description = "Faster generation"},
    {name = "High (1024x1024)", width = 1024, height = 1024, description = "Better quality (default)"},
    {name = "Ultra (1536x1536)", width = 1536, height = 1536, description = "Best quality (slow)"},
    {name = "Max (2048x2048)", width = 2048, height = 2048, description = "Maximum quality (very slow)"}
}

-- Common dimension presets
local dimension_presets = {
    {name = "Tiny (32x32)", width = 32, height = 32},
    {name = "Small (64x64)", width = 64, height = 64},
    {name = "Medium (128x128)", width = 128, height = 128},
    {name = "Large (256x256)", width = 256, height = 256},
    {name = "Portrait (64x96)", width = 64, height = 96},
    {name = "Landscape (96x64)", width = 96, height = 64}
}

-- Utility functions
local function format_time(seconds)
    if seconds < 60 then
        return string.format("%.1fs", seconds)
    else
        return string.format("%.1fm", seconds / 60)
    end
end

local function prepare_image_for_generation(output_method, image_mode)
    if not app.activeSprite.selection.isEmpty then 
        app.command.Cancel() 
    end
    
    local cel
    app.transaction("AI Generation Setup", function()
        local timestamp = os.date("%H:%M:%S")
        local layer_name = "AI Gen " .. timestamp
        local layer = app.activeSprite:newLayer{name = layer_name, colorMode = image_mode}
        app.activeLayer = layer
        
        local frame
        if output_method == "New Frame" then
            frame = app.activeSprite:newEmptyFrame(app.activeFrame.frameNumber + 1)
        else
            frame = app.activeFrame
        end
        
        cel = app.activeSprite:newCel(layer, frame)
    end)
    return cel
end

local function fetch_models_and_loras(callback)
    -- Connection check removed as per user request (Cloud workflow doesn't need it)
    if callback then callback() end
end

-- Capture current cel image for Image-to-Image
local function get_active_image_base64()
    if not app.activeSprite then return nil, "No active sprite found." end
    
    local layer = app.activeLayer
    local frame = app.activeFrame
    local cel = app.activeCel
    
    if not layer then return nil, "No active layer selected." end
    if not frame then return nil, "No active frame selected." end

    if not cel then
        return nil, string.format("No Cel found on Layer '%s' at Frame %d.\n(The cell is empty/nil on this frame)", layer.name, frame.frameNumber)
    end
    
    if cel.image.isEmpty then 
        -- app.alert("Warning: Aseprite reports this Cel is empty. Proceeding anyway...")
        -- We won't block here anymore because some users report false positives.
    end
    
    local image = app.activeCel.image
    local spec = image.spec
    
    -- We need to save to temp file to resize/convert before sending?
    -- Actually Aseprite Lua API doesn't have easy Base64 calc without saving.
    -- We'll save to a temporary png and read it back.
    
    local temp_path = "/tmp/pixelai_guide.png"
    image:saveAs(temp_path)
    
    local file = io.open(temp_path, "rb")
    if not file then return nil end
    
    local content = file:read("*all")
    file:close()
    
    return base64.encode(content)
end

local function generate_image(settings, callback)
    if is_generating then 
        app.alert("Generation already in progress. Please wait...")
        return 
    end
    
    is_generating = true
    local start_time = os.clock()

    -- Combine base and specific prompts
    local full_prompt = settings.prompt
    if settings.base_prompt and settings.base_prompt ~= "" then
        full_prompt = settings.base_prompt .. ", " .. settings.prompt
    end
    
    -- Handle Guide Image
    local init_image = nil
    if settings.use_guide_image then
        local err_msg
        init_image, err_msg = get_active_image_base64()
        if not init_image then
            app.alert("Error: 'Use Active Layer as Guide' is checked, but failed to get image.\n\nReason: " .. (err_msg or "Unknown error"))
            is_generating = false -- Reset flag
            return -- ABORT
        end
    end
    
    local request_data = {
        prompt = full_prompt,
        pixel_width = settings.pixel_width,
        pixel_height = settings.pixel_height,
        colors = settings.colors,
        api_key = settings.api_key,
        ai_provider = settings.ai_provider,
        init_image = init_image,
        strength = settings.strength
    }
    
    http_client.post(plugin_config.server_url .. "/generate", request_data, function(response, error)
        is_generating = false
        last_generation_time = os.clock() - start_time
        
        if callback then 
            callback(response, error) 
        end
    end)
end

local function P(str) return str end -- Dummy translation function

local function place_image_in_aseprite_raw(image_data, output_method)
    local pixel_data = base64.decode(image_data.base64)
    
    -- Save to temp file
    local timestamp = os.time()
    local temp_path = "/tmp/pixelai_gen_" .. timestamp .. ".png"
    
    local file = io.open(temp_path, "wb")
    if not file then
        app.alert("Failed to create temp file for image")
        return
    end
    file:write(pixel_data)
    file:close()
    
    -- Load from temp file
    local temp_sprite = Sprite{ fromFile=temp_path }
    if not temp_sprite then
        app.alert("Failed to load generated image")
        return
    end
    
    local source_image = temp_sprite.cels[1].image:clone()
    temp_sprite:close()
    os.remove(temp_path)
    
    -- Create target
    local image_mode = source_image.colorMode
    
    -- Create new sprite if none exists
    if not app.activeSprite then
        app.command.NewFile{
            width = source_image.width,
            height = source_image.height,
            colorMode = image_mode
        }
    end
    
    local cel = prepare_image_for_generation(output_method, image_mode)
    if not cel then 
        app.alert("Could not prepare canvas for image placement.")
        return 
    end
    
    app.transaction("Place AI Generated Image", function()
        cel.image:clear()
        cel.image:drawImage(source_image, Point(0, 0))
    end)
    
    app.refresh()
end

local function update_dialog_status(dlg)
    if dlg and dlg.data then
        -- Update server status (Removed)
        
        -- Update generation button
        if is_generating then
            dlg:modify{
                id = "generate", 
                enabled = false, 
                text = "Generating..."
            }
        else
            dlg:modify{
                id = "generate", 
                enabled = true, 
                text = "Generate Image"
            }
        end
        
        -- Update last generation time
        if last_generation_time > 0 then
            dlg:modify{
                id = "generation_time_label",
                text = "Last generation: " .. format_time(last_generation_time)
            }
        end
    end
end

-- Dialog state tracking
local show_advanced = false
local show_model_settings = false

local function open_advanced_dialog()
    local adv_dlg = Dialog("Advanced Settings")
    
    adv_dlg:slider{
        id = "steps",
        label = "Quality Steps:",
        min = 10,
        max = 50,
        value = current_settings.steps,
        onchange = function()
            current_settings.steps = adv_dlg.data.steps
        end
    }
    
    adv_dlg:slider{
        id = "guidance_scale",
        label = "Prompt Adherence:",
        min = 1,
        max = 20,
        value = current_settings.guidance_scale,
        onchange = function()
            current_settings.guidance_scale = adv_dlg.data.guidance_scale
        end
    }
    
    adv_dlg:number{
        id = "seed",
        label = "Seed (-1 = random):",
        text = tostring(current_settings.seed),
        decimals = 0,
        onchange = function()
            current_settings.seed = adv_dlg.data.seed
        end
    }
    
    adv_dlg:entry{
        id = "negative_prompt",
        label = "Negative Prompt:",
        text = current_settings.negative_prompt,
        onchange = function()
            current_settings.negative_prompt = adv_dlg.data.negative_prompt
        end
    }
    
    adv_dlg:button{text = "Close", onclick = function() adv_dlg:close() end}
    adv_dlg:show{wait = false}
end

local function open_model_dialog()
    local model_dlg = Dialog("Model Settings")
    
    model_dlg:combobox{
        id = "model_name",
        label = "Base Model:",
        options = available_models,
        option = current_settings.model_name,
        onchange = function()
            current_settings.model_name = model_dlg.data.model_name
            http_client.post(plugin_config.server_url .. "/load_model", {
                model_name = current_settings.model_name
            })
        end
    }
    
    model_dlg:separator{text = "Generation Quality"}
    
    model_dlg:combobox{
        id = "generation_quality",
        label = "Base Resolution:",
        options = (function()
            local options = {}
            for _, preset in ipairs(quality_presets) do
                table.insert(options, preset.name)
            end
            return options
        end)(),
        option = current_settings.generation_quality,
        onchange = function()
            current_settings.generation_quality = model_dlg.data.generation_quality
        end
    }
    
    model_dlg:label{text = "Higher resolution = better pixel art quality but slower generation"}
    
    model_dlg:separator{text = "Art Style"}
    
    model_dlg:combobox{
        id = "lora_model",
        label = "Art Style (LoRA):",
        options = available_loras,
        option = current_settings.lora_model,
        onchange = function()
            current_settings.lora_model = model_dlg.data.lora_model
        end
    }
    
    model_dlg:slider{
        id = "lora_strength",
        label = "Style Strength:",
        min = 0,
        max = 2,
        value = current_settings.lora_strength,
        onchange = function()
            current_settings.lora_strength = model_dlg.data.lora_strength
        end
    }
    
    model_dlg:button{text = "Close", onclick = function() model_dlg:close() end}
    model_dlg:show{wait = false}
end

local function create_main_dialog()
    if current_dialog then 
        current_dialog:close() 
    end
    
    local dlg = Dialog("PixelForgeAI")
    current_dialog = dlg
    
    -- Server status
    -- Server status UI removed

    -- API Key Field REMOVED (Handled by server .env now)
    
    dlg:separator{text="Configuration"}
    
    -- AI Provider
    dlg:combobox{
        id = "ai_provider",
        label = "AI Provider:",
        options = {"OpenAI (DALL-E)", "Stability AI"},
        option = current_settings.ai_provider,
        onchange = function()
            current_settings.ai_provider = dlg.data.ai_provider
            -- Stability AI always uses guide (Structure Control requires it)
            if current_settings.ai_provider == "Stability AI" then
                current_settings.use_guide_image = true
            end
            -- Update enabled state (not visibility) to avoid dialog resize
            local is_stab = (current_settings.ai_provider == "Stability AI")
            dlg:modify{id="stability_info", text = is_stab and "⚙️ Select your guide layer/frame, then generate." or "(Shape Control only available for Stability AI)"}
            dlg:modify{id="strength", enabled=is_stab}
            save_settings()
        end
    }
    
    -- Shape Control info label (always visible to prevent resize)
    local is_stability = (current_settings.ai_provider == "Stability AI")
    dlg:label{
        id = "stability_info",
        text = is_stability and "⚙️ Select your guide layer/frame, then generate." or "(Shape Control only available for Stability AI)"
    }
    
    dlg:slider{
        id = "strength",
        label = "AI Creativity:",
        min = 10,
        max = 100,
        value = math.floor(current_settings.strength * 100),
        enabled = is_stability,
        onchange = function()
            current_settings.strength = dlg.data.strength / 100.0
            save_settings()
        end
    }
    
    dlg:separator{}

    -- Base Style Prompt
    dlg:entry{
        id = "base_prompt",
        label = "Style (Every time):",
        text = current_settings.base_prompt,
        onchange = function()
            current_settings.base_prompt = dlg.data.base_prompt
            save_settings() -- Auto-save
        end
    }
    
    -- Main prompt
    dlg:entry{
        id = "prompt",
        label = "Image Prompt:",
        text = current_settings.prompt,
        onchange = function()
            current_settings.prompt = dlg.data.prompt
            save_settings() -- Auto-save
        end
    }
    
    -- Presets REMOVED
    
    -- Size settings
    dlg:combobox{
        id = "dimension_presets",
        label = "Size:",
        options = (function()
            local options = {}
            for _, preset in ipairs(dimension_presets) do
                table.insert(options, preset.name)
            end
            return options
        end)(),
        option = (function() 
            -- Find matching preset for current size
            for _, preset in ipairs(dimension_presets) do
                if preset.width == current_settings.pixel_width and preset.height == current_settings.pixel_height then
                    return preset.name
                end
            end
            return "Small (64x64)" -- fallback
        end)(),
        onchange = function()
            local selected_name = dlg.data.dimension_presets
            for _, preset in ipairs(dimension_presets) do
                if preset.name == selected_name then
                    current_settings.pixel_width = preset.width
                    current_settings.pixel_height = preset.height
                    break
                end
            end
        end
    }
    
    dlg:number{
        id = "colors",
        label = "Colors:",
        text = tostring(current_settings.colors),
        decimals = 0,
        onchange = function()
            current_settings.colors = dlg.data.colors
        end
    }
    
    dlg:check{
        id = "remove_background",
        text = "Remove Background",
        selected = current_settings.remove_background,
        onclick = function()
            current_settings.remove_background = dlg.data.remove_background
        end
    }
    
    dlg:combobox{
        id = "output_method",
        label = "Output:",
        option = current_settings.output_method,
        options = {"New Layer", "New Frame"},
        onchange = function()
            current_settings.output_method = dlg.data.output_method
        end
    }
    
    dlg:separator{}
    
    -- Settings buttons (Model Settings removed)
    -- dlg:button{text = "Model Settings", onclick = open_model_dialog} -- Legacy
    -- dlg:button{text = "Advanced Settings", onclick = open_advanced_dialog} -- Legacy
    
    dlg:separator{}
    
    -- Generation controls
    dlg:label{id="generation_time_label", text="Ready to generate"}
    
    dlg:button{
        id = "generate",
        text = "Generate Image",
        focus = true,
        onclick = function()
            -- Validation
            if current_settings.prompt == "" or current_settings.prompt == nil then
                app.alert("Please enter a prompt to generate an image.")
                return
            end
            
            -- Start generation
            update_dialog_status(dlg)
            
            generate_image(current_settings, function(response, error)
                update_dialog_status(dlg)
                
                if error then
                    app.alert("Generation failed: " .. error)
                elseif response and response.success and response.image then
                    place_image_in_aseprite_raw(response.image, current_settings.output_method)
                    
                    -- Show used seed but keep -1 for random generations
                    if response.seed and current_settings.seed == -1 then
                        app.alert("Image generated successfully!\nUsed seed: " .. response.seed .. "\n(Seed remains random for next generation)")
                    else
                        app.alert("Image generated successfully!")
                    end
                else
                    local error_msg = response and response.error or "Unknown error occurred"
                    app.alert("Generation failed: " .. error_msg)
                end
            end)
        end
    }
    
    dlg:button{text = "Close", onclick = function() dlg:close() end}
    
    -- Show dialog
    dlg:show{wait = false}
    
    -- Initial status update
    update_dialog_status(dlg)
end

-- Only run when explicitly called (not on script load)
-- print("Loading Local AI Generator v2.0...")
fetch_models_and_loras(create_main_dialog)