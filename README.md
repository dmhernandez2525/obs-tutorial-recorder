# OBS Tutorial Recorder for macOS

Automated OBS Studio setup for recording coding tutorials with ISO recordings (separate files per source) for maximum editing flexibility.

## Features

- **One-click session start**: Double-click an app, enter project name, and start recording
- **ISO recordings**: Each source (screens, camera) recorded separately via Source Record plugin
- **Automatic file collection**: All ISO recordings automatically moved to project folder
- **Project organization**: Dated folders with `raw/` and `exports/` subdirectories
- **Automatic remuxing**: Option to convert recordings to MP4 after stopping
- **Metadata tracking**: JSON file tracks all recordings and details
- **WebSocket automation**: Controls OBS programmatically

## Requirements

### Software
- macOS 12.0 or later
- [Homebrew](https://brew.sh/)

### Hardware (customize for your setup)
- Camera (e.g., Sony ZV-E10, webcam, or capture card)
- Microphone (e.g., FIFINE, Blue Yeti, or built-in)
- One or more displays

## Quick Start

### 1. Clone and Install

```bash
git clone https://github.com/YOUR_USERNAME/obs-tutorial-recorder.git
cd obs-tutorial-recorder
./install.sh
```

The installer will:
- Install dependencies (websocat, ffmpeg)
- Install OBS Studio (if not present)
- Install Source Record plugin for ISO recordings
- Create Desktop apps
- Set up folder structure

### 2. Configure OBS (First Time Only)

After installation, open OBS and configure:

#### Enable WebSocket Server
1. Go to **Tools > WebSocket Server Settings**
2. Check **"Enable WebSocket server"**
3. Set Port to **4455**
4. **Uncheck** "Enable Authentication"
5. Click **OK**

#### Add Your Sources
In OBS, click **+** in Sources panel:
1. **macOS Screen Capture** - Add one for each monitor
2. **Video Capture Device** - Select your camera
3. **Audio Input Capture** - Select your microphone

#### Add Source Record Filter (For ISO Recordings)
For each source you want recorded separately:
1. Right-click the source > **Filters**
2. Click **+** under "Effect Filters"
3. Select **"Source Record"**
4. Set format to **MOV** or **MKV**
5. Leave file path empty (uses ~/Movies default)
6. Click **Close**

### 3. Grant Permissions
In **System Settings > Privacy & Security**, enable:
- Screen Recording: OBS
- Camera: OBS
- Microphone: OBS
- Accessibility: Terminal

### 4. Start Recording
Double-click **Start Tutorial.app** on your Desktop!

## Usage

### Starting a Recording

1. Double-click **Start Tutorial.app** on Desktop
2. Select existing project OR create new one
3. OBS launches and connects via WebSocket
4. Recording starts after 5-second countdown

### Stopping a Recording

1. Double-click **Stop Tutorial.app** on Desktop
2. Main recording stops
3. All ISO recordings are collected from ~/Movies
4. Files are moved to your project's `raw/` folder
5. Option to remux to MP4
6. Project folder opens in Finder

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
    │   ├── Screen 1.mov          # ISO from Source Record
    │   ├── Screen 2.mov          # ISO from Source Record
    │   ├── Camera - ZV-E10.mov   # ISO from Source Record
    │   └── 2026-01-18 13-00-00.mov  # Main composite
    ├── exports/
    └── metadata.json
```

## How ISO Recording Works

The **Source Record plugin** adds a filter to each OBS source that records it independently:

| Source | Output File | Use Case |
|--------|-------------|----------|
| Screen 1 | Screen 1.mov | Main coding display |
| Screen 2 | Screen 2.mov | Reference/documentation |
| Camera | Camera.mov | Picture-in-picture, reactions |
| Main Output | timestamp.mov | Composite fallback |

**Benefits**:
- Full resolution per source (no quality loss from combining)
- Crop/reframe any source in post-production
- Mix and match sources during editing
- Keep or discard sources as needed

## Customizing for Your Hardware

### Different Microphone

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

macOS display indices:
- Display 0 = Primary display
- Display 1, 2, etc. = Additional displays

In OBS: Sources > macOS Screen Capture > Properties > Select display

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

**Solutions**:
1. Check OBS has sources configured
2. Verify no permission dialogs are blocking OBS
3. Check OBS Output settings are valid

### Source Record Files Not Collected

**Solutions**:
1. Verify Source Record filter is added to each source
2. Check ~/Movies for the files manually
3. Ensure files have finished writing before stopping

### No Audio in Recording

**Solutions**:
1. Check microphone is selected in OBS Audio Input Capture
2. Verify audio levels show in OBS Audio Mixer
3. Check microphone permissions in System Settings

### Camera Not Showing

**Solutions**:
1. Check camera is connected and powered on
2. Grant Camera permission to OBS
3. For Sony ZV-E10: Menu > Network > USB > USB Streaming

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install.sh` | Complete installer (run from repo root) |
| `scripts/start-tutorial.sh` | Start new recording session |
| `scripts/stop-tutorial.sh` | Stop recording and collect ISO files |
| `scripts/toggle-recording.sh` | Combined start/stop |
| `scripts/setup-sources.sh` | Add sources to OBS via WebSocket |
| `scripts/obs-websocket.sh` | WebSocket helper functions |

## OBS Settings

### Recommended Recording Settings

| Setting | Value |
|---------|-------|
| Output Format | MOV or MKV |
| Encoder | Apple VT H264 Hardware |
| Resolution | 1920x1080 per source |
| Frame Rate | 30 fps |
| Audio Sample Rate | 48 kHz |

### Source Record Filter Settings

| Setting | Recommended Value |
|---------|-------------------|
| Record Mode | Recording |
| Format | MOV or MKV |
| Path | (leave empty for ~/Movies) |

## macOS Permissions Required

| Permission | App |
|------------|-----|
| Screen Recording | OBS |
| Camera | OBS |
| Microphone | OBS |
| Accessibility | Terminal |

## License

MIT License - See LICENSE file for details.
