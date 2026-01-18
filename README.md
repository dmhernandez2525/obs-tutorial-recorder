# OBS Tutorial Recorder for macOS

Automated OBS Studio setup for recording coding tutorials with separate video tracks, organized file management, and one-click session launching.

## Features

- **One-click session start**: Double-click an app, enter project name, and you're ready to record
- **Automatic folder organization**: Creates dated project folders with `raw/` and `exports/` subdirectories
- **Multi-track recording**: Screen capture and camera recorded as separate video tracks for flexible post-production
- **Hardware verification**: Checks for camera and microphone before recording
- **Automatic remuxing**: Converts MKV to MP4 after recording while preserving the original
- **Metadata tracking**: JSON file tracks recording details, timestamps, and equipment used
- **Simultaneous dictation support**: macOS dictation works while OBS records

## Hardware Requirements

| Component | Model | Connection |
|-----------|-------|------------|
| Camera | Sony ZV-E10 | USB-C (720p) or HDMI capture card (1080p+) |
| Microphone | FIFINE SC3 | USB |
| Computer | Mac (Apple Silicon or Intel) | - |

## Software Requirements

- macOS 12.0 or later
- [OBS Studio](https://obsproject.com/) 28.0+ (installed via Homebrew)
- [Homebrew](https://brew.sh/)
- ffmpeg (for remuxing)
- websocat (for OBS WebSocket control)

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/dmhernandez2525/obs-tutorial-recorder.git
cd obs-tutorial-recorder

# Run the installer
./scripts/install.sh
```

### Manual Install

1. **Install dependencies**:
```bash
brew install obs ffmpeg websocat
```

2. **Clone and setup**:
```bash
git clone https://github.com/dmhernandez2525/obs-tutorial-recorder.git
cd obs-tutorial-recorder
chmod +x scripts/*.sh
```

3. **Run OBS setup**:
```bash
./scripts/setup-obs.sh
```

4. **Create Desktop apps** (optional):
```bash
./scripts/install.sh
```

## Configuration

### First-Time OBS Setup

After installation, run the setup script:

```bash
./scripts/setup-obs.sh
```

This creates OBS profiles and provides step-by-step instructions for:

1. **Enabling WebSocket Server** (Tools > WebSocket Server Settings)
2. **Adding Display Capture** source
3. **Adding Video Capture Device** (Sony ZV-E10)
4. **Adding Audio Input Capture** (FIFINE SC3)
5. **Configuring multi-track recording**
6. **Setting up hotkeys**

### OBS Recording Settings

The setup configures OBS with these optimal settings:

| Setting | Value |
|---------|-------|
| Output Format | MKV (Matroska) |
| Video Encoder | Apple VT H264 Hardware |
| Bitrate | 40 Mbps |
| Resolution | 1920x1080 |
| Frame Rate | 30 fps |
| Audio Sample Rate | 48 kHz |

### Multi-Track Recording

For separate video tracks in post-production:

1. Go to **Settings > Output > Recording**
2. Set **Recording Format** to Matroska (.mkv)
3. Under **Audio Track**, enable multiple tracks
4. In **Edit > Advanced Audio Properties**, assign sources to different tracks

This allows you to independently edit screen capture and camera footage in DaVinci Resolve or other editors.

## Usage

### Starting a Recording Session

**Option 1: Desktop App**
1. Double-click `Start Tutorial.app` on your Desktop
2. Enter a project name when prompted
3. Click "Start Recording"
4. OBS opens with the correct output path configured
5. Press `Cmd+Shift+R` to start recording

**Option 2: Command Line**
```bash
./scripts/start-tutorial.sh
```

### Stopping a Recording

**Option 1: Desktop App**
1. Double-click `Stop Tutorial.app`
2. Recording stops and remuxes to MP4
3. Project folder opens in Finder

**Option 2: Command Line**
```bash
./scripts/stop-tutorial.sh
```

**Option 3: Hotkey**
- Press `Cmd+Shift+S` in OBS

### Toggle Script (Combined Start/Stop)

```bash
./scripts/toggle-recording.sh
```

Or use `Toggle Recording.app` on Desktop.

## Folder Structure

Each recording session creates:

```
~/Desktop/Tutorial Recordings/
└── 2026-01-18_project-name/
    ├── raw/
    │   ├── recording_001.mkv  (original multi-track)
    │   └── recording_001.mp4  (remuxed copy)
    ├── exports/
    │   └── (for edited final versions)
    └── metadata.json
```

### metadata.json Example

```json
{
  "projectName": "Authentication Tutorial",
  "dateCreated": "2026-01-18T14:30:00Z",
  "recordings": [
    {
      "filename": "recording_001.mkv",
      "startTime": "2026-01-18T14:32:15Z",
      "duration": "1847 seconds",
      "notes": ""
    }
  ],
  "equipment": {
    "camera": "Sony ZV-E10 (USB-C)",
    "microphone": "fifine SC3",
    "captureCard": "Not connected"
  },
  "tags": [],
  "description": ""
}
```

## Global Hotkeys

Configure these in OBS (Settings > Hotkeys):

| Action | Hotkey |
|--------|--------|
| Start Recording | `Cmd+Shift+R` |
| Stop Recording | `Cmd+Shift+S` |
| Pause Recording | `Cmd+Shift+P` |

Hotkeys work even when OBS is not focused.

## macOS Permissions

Grant these permissions when prompted (System Settings > Privacy & Security):

| Permission | App | Purpose |
|------------|-----|---------|
| Screen Recording | OBS | Capture display |
| Camera | OBS | Access Sony ZV-E10 |
| Microphone | OBS | Access FIFINE mic |
| Accessibility | Terminal | AppleScript automation |
| Automation | Terminal > OBS | Control OBS |

## Audio Routing (Dictation Support)

macOS allows multiple apps to access the same microphone simultaneously. By default:
- OBS captures audio from FIFINE for recording
- macOS Dictation can use the same mic for speech-to-text
- Both work at the same time

If you experience conflicts, see [docs/audio-routing.md](docs/audio-routing.md) for advanced configuration options.

## Troubleshooting

### OBS doesn't detect camera

1. Check USB-C cable connection
2. On Sony ZV-E10: Menu > Network > USB > USB Streaming
3. Verify camera appears in System Information > USB
4. Try a different USB-C port

### WebSocket connection fails

1. In OBS: Tools > WebSocket Server Settings
2. Enable "Enable WebSocket server"
3. Port should be 4455
4. Disable authentication (or set password in scripts)

### Recording path not set automatically

1. Ensure websocat is installed: `brew install websocat`
2. Check OBS WebSocket is enabled
3. Manually set path: Settings > Output > Recording Path

### Dictation not working while recording

1. Both should work simultaneously by default
2. Check System Settings > Keyboard > Dictation is enabled
3. Verify microphone selection in both OBS and System Settings
4. See [docs/audio-routing.md](docs/audio-routing.md) for advanced options

### MKV not remuxing to MP4

1. Ensure ffmpeg is installed: `brew install ffmpeg`
2. Check the MKV file isn't corrupted
3. Try manual remux: `ffmpeg -i input.mkv -c copy output.mp4`

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install.sh` | Install dependencies and create Desktop apps |
| `setup-obs.sh` | Configure OBS profiles and scenes |
| `start-tutorial.sh` | Start new recording session |
| `stop-tutorial.sh` | Stop recording and post-process |
| `toggle-recording.sh` | Combined start/stop toggle |

## File Locations

| Item | Path |
|------|------|
| Scripts | `~/Projects/obs-tutorial-recorder/scripts/` |
| Desktop Apps | `~/Desktop/*.app` |
| Recordings | `~/Desktop/Tutorial Recordings/` |
| OBS Profiles | `~/Library/Application Support/obs-studio/basic/profiles/` |
| OBS Scenes | `~/Library/Application Support/obs-studio/basic/scenes/` |

## Post-Production Workflow

1. **Open project folder** from Finder
2. **Import MKV** into DaVinci Resolve (or your editor)
3. **Separate tracks** appear as individual clips
4. **Edit** screen capture and camera independently
5. **Export** final video to the `exports/` folder
6. **Update metadata.json** with notes if desired

## Tips for Better Recordings

1. **Test audio levels** before starting - aim for peaks around -12dB
2. **Use a second monitor** for OBS so it's not in your screen capture
3. **Close unnecessary apps** to reduce CPU usage and notifications
4. **Record in MKV** - it's recoverable if OBS crashes mid-recording
5. **Keep the MP4 remux** - it's more compatible with editors
6. **Add notes to metadata.json** immediately after recording while details are fresh

## Contributing

Issues and pull requests welcome.

## License

MIT License - See LICENSE file for details.
