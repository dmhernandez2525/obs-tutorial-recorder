# OBS Tutorial Recorder for macOS

Automated OBS Studio setup for recording coding tutorials with organized file management and one-click session launching.

## Features

- **One-click session start**: Double-click an app, enter project name, and start recording
- **Project selector**: Choose from existing projects or create new ones
- **Automatic folder organization**: Creates dated project folders with `raw/` and `exports/` subdirectories
- **Automatic remuxing**: Converts recordings to MP4 after stopping
- **Metadata tracking**: JSON file tracks recording details and timestamps
- **WebSocket automation**: Controls OBS programmatically for seamless workflow

## Requirements

### Software
- macOS 12.0 or later
- [OBS Studio](https://obsproject.com/) 28.0+
- [Homebrew](https://brew.sh/)

### Hardware (customize for your setup)
- Camera (e.g., Sony ZV-E10, webcam, or capture card)
- Microphone (e.g., FIFINE, Blue Yeti, or built-in)
- One or more displays

## Installation

### Step 1: Install Dependencies

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required packages
brew install obs ffmpeg websocat
```

### Step 2: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/obs-tutorial-recorder.git
cd obs-tutorial-recorder
chmod +x scripts/*.sh
```

### Step 3: Run Installer

```bash
./scripts/install.sh
```

This creates Desktop apps and the recordings folder.

## First-Time OBS Setup

**IMPORTANT**: Before the automation works, you must configure OBS once:

### 1. Enable WebSocket Server

1. Open OBS
2. Go to **Tools > WebSocket Server Settings**
3. Check **"Enable WebSocket server"**
4. Set Port to **4455**
5. **Uncheck** "Enable Authentication"
6. Click **OK**

### 2. Add Sources Manually

In OBS, add your sources by clicking **+** in the Sources panel:

1. **macOS Screen Capture** - Select your display(s)
2. **Video Capture Device** - Select your camera
3. **Audio Input Capture** - Select your microphone

### 3. Configure Your Microphone

The default setup uses "default" audio device. To use a specific microphone:

1. In OBS Sources, right-click your **Audio Input Capture**
2. Click **Properties**
3. Select your specific microphone from the dropdown
4. Click **OK**

### 4. Configure Your Camera

1. In OBS Sources, right-click your **Video Capture Device**
2. Click **Properties**
3. Select your camera from the Device dropdown
4. Set resolution/preset as desired
5. Click **OK**

### 5. Arrange Sources

- Drag sources in the preview to position them
- Resize by dragging corners
- Right-click for transform options

## Creating Desktop Apps

The installer creates these automatically, but if you need to create them manually:

### Method 1: Using the Install Script

```bash
./scripts/install.sh
```

### Method 2: Manual Creation

For each app (Start Tutorial, Stop Tutorial, Toggle Recording):

1. **Create the app bundle structure**:
```bash
# Example for Start Tutorial
mkdir -p ~/Desktop/"Start Tutorial.app"/Contents/MacOS
mkdir -p ~/Desktop/"Start Tutorial.app"/Contents/Resources
```

2. **Create Info.plist**:
```bash
cat > ~/Desktop/"Start Tutorial.app"/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.tutorial-recorder.start</string>
    <key>CFBundleName</key>
    <string>Start Tutorial</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF
```

3. **Create launcher script**:
```bash
cat > ~/Desktop/"Start Tutorial.app"/Contents/MacOS/launcher << 'EOF'
#!/bin/zsh
osascript -e 'tell application "Terminal"
    activate
    do script "PATH_TO_REPO/scripts/start-tutorial.sh"
end tell'
EOF
chmod +x ~/Desktop/"Start Tutorial.app"/Contents/MacOS/launcher
```

Replace `PATH_TO_REPO` with your actual repository path (e.g., `~/Projects/obs-tutorial-recorder`).

Repeat for Stop Tutorial (`stop-tutorial.sh`) and Toggle Recording (`toggle-recording.sh`).

## Customizing for Your Hardware

### Different Microphone

Edit `scripts/setup-sources.sh` or configure in OBS directly:

```bash
# Find your microphone's device ID
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep audio
```

In OBS: Sources > Audio Input Capture > Properties > Select your device

### Different Camera

```bash
# Find your camera's device ID
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep video
```

In OBS: Sources > Video Capture Device > Properties > Select your device

### Different/Multiple Displays

macOS assigns display indices starting from 0:
- Display 0 = Primary display (usually MacBook screen or main external)
- Display 1, 2, etc. = Additional displays

In OBS: Sources > macOS Screen Capture > Properties > Select display

## Usage

### Starting a Recording

1. Double-click **Start Tutorial.app** on Desktop
2. Select existing project OR create new one
3. Wait for OBS to connect (WebSocket)
4. Recording starts automatically after 5-second countdown

### Stopping a Recording

1. Double-click **Stop Tutorial.app** on Desktop
2. Recording stops via WebSocket
3. File is moved to project folder and remuxed to MP4
4. Project folder opens in Finder

### Command Line Usage

```bash
# Start recording session
./scripts/start-tutorial.sh

# Stop recording
./scripts/stop-tutorial.sh

# Toggle (start if not recording, stop if recording)
./scripts/toggle-recording.sh
```

## Folder Structure

```
~/Desktop/Tutorial Recordings/
└── 2026-01-18_project-name/
    ├── raw/
    │   ├── recording.mov
    │   └── recording.mp4
    ├── exports/
    └── metadata.json
```

## Troubleshooting

### WebSocket Connection Fails

**Symptoms**: "Could not connect to OBS WebSocket" error

**Solutions**:
1. Ensure OBS is running
2. Check **Tools > WebSocket Server Settings**:
   - "Enable WebSocket server" is checked
   - Port is 4455
   - "Enable Authentication" is unchecked
3. Restart OBS after changing settings

### Recording Doesn't Start

**Symptoms**: Script says "Recording started" but OBS isn't recording

**Solutions**:
1. Check OBS has sources configured (not empty scene)
2. Verify no permission dialogs are blocking OBS
3. Check OBS Output settings are valid

### No Audio in Recording

**Solutions**:
1. Check microphone is selected in OBS Audio Input Capture
2. Verify audio levels show in OBS Audio Mixer
3. Check microphone permissions in System Settings

### Camera Not Showing

**Solutions**:
1. Check camera is connected and powered on
2. Grant Camera permission to OBS (System Settings > Privacy > Camera)
3. Try selecting device again in OBS Source Properties
4. For Sony ZV-E10: Menu > Network > USB > USB Streaming

### Screen Capture Permission

If screen capture shows black:
1. Go to **System Settings > Privacy & Security > Screen Recording**
2. Enable OBS
3. Restart OBS

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install.sh` | Install dependencies and create Desktop apps |
| `setup-obs.sh` | Display OBS configuration instructions |
| `setup-sources.sh` | Add sources to OBS via WebSocket |
| `start-tutorial.sh` | Start new recording session |
| `stop-tutorial.sh` | Stop recording and post-process |
| `toggle-recording.sh` | Combined start/stop |
| `obs-websocket.sh` | WebSocket helper functions |

## OBS Settings

### Recommended Recording Settings

| Setting | Value |
|---------|-------|
| Output Format | MOV or MKV |
| Encoder | Apple VT H264 Hardware |
| Resolution | 1920x1080 |
| Frame Rate | 30 fps |
| Audio Sample Rate | 48 kHz |

### Recording Path

OBS saves to `~/Movies` by default. The stop script automatically moves recordings to your project's `raw/` folder.

## macOS Permissions Required

Grant these in System Settings > Privacy & Security:

| Permission | App |
|------------|-----|
| Screen Recording | OBS |
| Camera | OBS |
| Microphone | OBS |
| Accessibility | Terminal (for AppleScript automation) |

## License

MIT License - See LICENSE file for details.
