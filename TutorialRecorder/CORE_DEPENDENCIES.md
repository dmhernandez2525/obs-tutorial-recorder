# Core Dependencies - DO NOT REMOVE

## CRITICAL WARNING

This document describes the **essential dependencies** that Tutorial Recorder requires to function properly. **DO NOT REMOVE OR MODIFY** these components without understanding their purpose.

---

## Required Components Overview

| Component | Purpose | Removal Impact |
|-----------|---------|----------------|
| **Source Record Plugin** | ISO recording (separate files per source) | No individual source files |
| **whisper-cpp (whisper-cli)** | Local AI transcription | No automatic transcription |
| **Whisper Models** | AI speech recognition | Transcription will fail |
| **ffmpeg** | Audio extraction & conversion | No audio processing |
| **websocat** | OBS WebSocket communication | Cannot control OBS |
| **OBS Studio** | Recording engine | No recording capability |
| **OBS WebSocket Server** | Remote control interface | Cannot automate OBS |

---

## 1. Source Record Plugin (CRITICAL)

### What It Does
The **Source Record plugin** enables **ISO recording** - recording each source (screen, camera, microphone) as a **separate file**. This is essential for:
- Post-production flexibility (color grade camera separately)
- Audio editing (clean up voice without affecting screen)
- Multi-camera editing (switch angles in post)
- Backup redundancy (if composite fails, individual sources remain)

### Location
```
~/Library/Application Support/obs-studio/plugins/source-record.plugin/
```

### Installation
```bash
# The plugin should be installed via OBS Plugin Browser:
# OBS > Tools > Scripts > Get More Scripts... (or Plugin Browser)
# Search for "Source Record" and install

# Alternative: Manual installation
# Download from: https://obsproject.com/forum/resources/source-record.1285/
```

### How It Works in Tutorial Recorder
When you start a recording, the app automatically:
1. Gets the list of sources in your scene (screens, cameras, audio)
2. Adds an "ISO_Record" filter to each source
3. Configures each filter to save to: `project/raw/SourceName.mov`

### Verification
```bash
# Check if plugin is installed
ls -la ~/Library/Application\ Support/obs-studio/plugins/ | grep source-record
```

### DO NOT:
- Remove the `source-record.plugin` folder
- Disable the "ISO_Record" filters in OBS (they're added automatically)
- Delete the plugin via OBS Plugin Browser

---

## 2. Whisper.cpp (whisper-cli) - Local AI Transcription

### What It Does
**whisper-cli** is a local AI transcription engine based on OpenAI's Whisper model. It:
- Converts speech to text **entirely on your Mac** (no cloud/internet needed)
- Runs automatically after each recording session
- Outputs transcript files alongside your recordings

### Installation
```bash
# Install via Homebrew
brew install whisper-cpp

# Verify installation
which whisper-cli
# Should output: /opt/homebrew/bin/whisper-cli
```

### Models Location
```
~/.cache/whisper/
```

### Available Models
| Model | Size | Speed | Accuracy | Recommended For |
|-------|------|-------|----------|-----------------|
| tiny | 75MB | Fastest | Lower | Quick drafts |
| base | 150MB | Fast | Good | General use |
| **small** | 500MB | Medium | **Better** | **Default - Best balance** |
| medium | 1.5GB | Slower | Highest | Final transcripts |

### Download Models
```bash
# Models are downloaded automatically, or manually:
cd ~/.cache/whisper
curl -L -O https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin
```

### DO NOT:
- Uninstall whisper-cpp via `brew uninstall whisper-cpp`
- Delete the `~/.cache/whisper/` folder
- Remove the model files (`ggml-*.bin`)

---

## 3. FFmpeg - Audio/Video Processing

### What It Does
**ffmpeg** is used for:
- Extracting audio from video recordings
- Converting audio formats (AAC to WAV for Whisper)
- Any future video processing needs

### Installation
```bash
brew install ffmpeg

# Verify
which ffmpeg
# Should output: /opt/homebrew/bin/ffmpeg
```

### DO NOT:
- Uninstall ffmpeg via `brew uninstall ffmpeg`

---

## 4. Websocat - OBS WebSocket Client

### What It Does
**websocat** enables Tutorial Recorder to communicate with OBS via WebSocket:
- Start/stop recording
- Switch profiles
- Create/configure sources
- Add filters (including Source Record)

### Installation
```bash
brew install websocat

# Verify
which websocat
# Should output: /opt/homebrew/bin/websocat
```

### DO NOT:
- Uninstall websocat via `brew uninstall websocat`

---

## 5. OBS Studio Configuration

### WebSocket Server
OBS WebSocket Server **must be enabled** for Tutorial Recorder to work.

**Settings:**
- **Enable WebSocket server**: ON
- **Server Port**: 4455 (default)
- **Enable Authentication**: OFF (for local use) or configure password

**Location in OBS:**
```
OBS > Tools > WebSocket Server Settings
```

### Required Profiles
Tutorial Recorder creates and manages these profiles:
- `Mac-MultiScreen` - For multi-monitor setups
- `MacBook-Single` - For single display + webcam
- `PC-10Cameras` - For multi-camera setups

### DO NOT:
- Delete the OBS profiles created by Tutorial Recorder
- Disable the WebSocket Server
- Change the WebSocket port without updating the app

---

## Complete Recording & Processing Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RECORDING PHASE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. User clicks "Start Recording"                                   │
│     ↓                                                                │
│  2. App launches OBS (if not running)                               │
│     ↓                                                                │
│  3. App connects via WebSocket (websocat)                           │
│     ↓                                                                │
│  4. App switches to correct profile (Mac-MultiScreen, etc.)         │
│     ↓                                                                │
│  5. App verifies/configures sources (screens, cameras, audio)       │
│     ↓                                                                │
│  6. App adds Source Record filters to each source ← ISO RECORDING   │
│     ↓                                                                │
│  7. App starts OBS recording                                        │
│     ↓                                                                │
│  8. OBS records:                                                    │
│     • Composite video (all sources combined)                        │
│     • Screen_1.mov (Source Record filter)                           │
│     • Screen_2.mov (Source Record filter)                           │
│     • FaceTime_HD_Camera.mov (Source Record filter)                 │
│     • Built-in_Microphone.mov (Source Record filter)                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      POST-RECORDING PHASE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. User clicks "Stop Recording"                                    │
│     ↓                                                                │
│  2. App stops OBS recording                                         │
│     ↓                                                                │
│  3. App collects all files to project/raw/ folder                   │
│     ↓                                                                │
│  4. App extracts audio (ffmpeg) → audio.aac                         │
│     ↓                                                                │
│  5. App converts audio to WAV (ffmpeg) → audio_temp.wav             │
│     ↓                                                                │
│  6. App runs transcription (whisper-cli) → transcript.txt           │
│     ↓                                                                │
│  7. App cleans up temp files                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Output File Structure

After a recording session, your project folder looks like this:

```
~/Recordings/TutorialRecorder/
└── 2026-01-21_my-tutorial/
    ├── metadata.json
    ├── session.log
    └── raw/
        └── 2026-01-21 14-30-00/
            ├── composite.mov          ← Combined recording
            ├── Screen_1.mov           ← ISO: Display capture
            ├── Screen_2.mov           ← ISO: Second display
            ├── FaceTime_HD_Camera.mov ← ISO: Camera
            ├── Built-in_Microphone.mov← ISO: Audio (with video container)
            ├── audio.aac              ← Extracted audio only
            └── transcript.txt         ← AI transcription
```

---

## Troubleshooting

### ISO Recording Not Working

**Symptom:** Only composite.mov is created, no individual source files

**Causes & Fixes:**

1. **Source Record plugin not installed**
   ```bash
   ls ~/Library/Application\ Support/obs-studio/plugins/ | grep source
   # If empty, install the plugin via OBS Plugin Browser
   ```

2. **Filters not being added**
   - Check session.log for errors about "Source Record"
   - Manually check OBS: Right-click source > Filters > Look for "ISO_Record"

3. **Plugin incompatible with OBS version**
   - Update OBS to latest version
   - Reinstall Source Record plugin

### Transcription Not Working

**Symptom:** No transcript.txt file created

**Causes & Fixes:**

1. **whisper-cli not installed**
   ```bash
   which whisper-cli
   # If nothing, run: brew install whisper-cpp
   ```

2. **Model not downloaded**
   ```bash
   ls ~/.cache/whisper/
   # Should contain ggml-small.en.bin (or your chosen model)
   ```

3. **ffmpeg not installed (can't convert audio)**
   ```bash
   which ffmpeg
   # If nothing, run: brew install ffmpeg
   ```

4. **Transcription disabled**
   - Check Tutorial Recorder > Preferences > Transcription > Enabled

### OBS Not Responding to Commands

**Symptom:** App can't connect to OBS or commands fail

**Causes & Fixes:**

1. **WebSocket server disabled**
   - OBS > Tools > WebSocket Server Settings > Enable

2. **websocat not installed**
   ```bash
   which websocat
   # If nothing, run: brew install websocat
   ```

3. **Wrong port**
   - Default is 4455, ensure OBS and app match

---

## Quick Installation Script

If you need to reinstall all dependencies:

```bash
#!/bin/bash
# Tutorial Recorder Dependencies Installer

echo "Installing Tutorial Recorder dependencies..."

# Install Homebrew packages
brew install whisper-cpp ffmpeg websocat

# Create whisper models directory
mkdir -p ~/.cache/whisper

# Download default model (small)
echo "Downloading Whisper small model..."
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin" \
     -o ~/.cache/whisper/ggml-small.en.bin

echo ""
echo "MANUAL STEP REQUIRED:"
echo "Install Source Record plugin in OBS:"
echo "  1. Open OBS"
echo "  2. Tools > Scripts > Get More Scripts (or Plugin Browser)"
echo "  3. Search for 'Source Record'"
echo "  4. Click Install"
echo ""
echo "Done! All dependencies installed."
```

---

## Version Compatibility

| Component | Minimum Version | Tested With |
|-----------|-----------------|-------------|
| OBS Studio | 28.0+ | 32.0.4 |
| OBS WebSocket | 5.0+ (built-in) | 5.6.3 |
| Source Record | 0.3.0+ | Latest |
| whisper-cpp | 1.5.0+ | Latest |
| ffmpeg | 5.0+ | Latest |
| websocat | 1.11+ | Latest |
| macOS | 12.0+ | 15.x |

---

## Summary

**NEVER REMOVE:**
1. `~/Library/Application Support/obs-studio/plugins/source-record.plugin/`
2. `/opt/homebrew/bin/whisper-cli` (or equivalent)
3. `~/.cache/whisper/*.bin` model files
4. `/opt/homebrew/bin/ffmpeg`
5. `/opt/homebrew/bin/websocat`

**ALWAYS KEEP ENABLED:**
1. OBS WebSocket Server (port 4455)
2. Tutorial Recorder profiles in OBS
3. Transcription in Tutorial Recorder preferences

These components work together to provide the full recording → splitting → transcription workflow. Removing any of them will break part of the automation.
