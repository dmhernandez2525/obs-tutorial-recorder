# OBS Tutorial Recorder for macOS

Automated OBS Studio setup for recording coding tutorials with ISO recordings (separate files per source) for maximum editing flexibility.

## Features

### Recording & Automation
- **Fully automated OBS configuration**: No manual OBS setup required - profiles configured automatically via WebSocket
- **First-time setup wizard**: Beautiful multi-step wizard guides you through profile configuration on first launch
- **Multiple profile support**: Switch between different recording setups (Mac multi-screen, MacBook single, PC with multiple cameras)
- **Smart profile management**: Create, edit, and switch profiles from the menubar app
- **One-click session start**: Select your profile, enter project name, and start recording
- **ISO recordings**: Each source (screens, camera) recorded separately via Source Record plugin
- **Automatic audio extraction**: Audio track automatically extracted to separate AAC file
- **Automatic transcription**: Audio transcribed to text using Whisper AI (runs locally, no API needed)
- **Automatic file collection**: All ISO recordings automatically moved to project folder
- **Project organization**: Dated folders with `raw/` and `exports/` subdirectories

### Cloud Sync & Organization
- **Cloud sync**: Automatic backup to Google Drive via rclone integration
- **Sync Status Panel**: Google Drive-style panel showing sync activity, file status, and quick actions
- **Animated sync icon**: Menubar icon animates during sync operations
- **Auto-sync**: Optionally sync to cloud automatically after each recording
- **Metadata tracking**: JSON file tracks all recordings and details

### User Interface
- **Menubar app**: Native macOS app with status indicator and quick controls
- **Progress indicators**: Visual feedback during start/stop operations with always-on-top windows
- **Session logging**: Detailed logs for debugging issues
- **Auto-close OBS**: Configurable setting to automatically close OBS after recording
- **WebSocket automation**: Controls OBS programmatically - profile switching, scene creation, source management

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
- Install dependencies (websocat, ffmpeg, rclone, whisper-cpp)
- Download Whisper AI model for transcription
- Install OBS Studio (if not present)
- Install Source Record plugin for ISO recordings
- Build native menubar app
- Set up folder structure

### 2. Configure OBS WebSocket (First Time Only)

After installation, open OBS and enable the WebSocket server:

#### Enable WebSocket Server
1. Go to **Tools > WebSocket Server Settings**
2. Check **"Enable WebSocket server"**
3. Set Port to **4455**
4. **Uncheck** "Enable Authentication"
5. Click **OK**

**That's it!** The app will automatically configure your OBS profiles, scenes, and sources via WebSocket.

### 3. First-Time Setup Wizard

When you launch Tutorial Recorder for the first time, a setup wizard appears:

1. **Welcome Screen**: Click "Get Started"
2. **Choose Profile**: Select from presets or create custom:
   - **Mac Multi-Screen** - Multiple displays + external cameras
   - **MacBook Single** - Built-in display + FaceTime camera
   - **PC 7 Cam + Mic** - Single display + 7 cameras + 7 mics
   - **＋ Create Custom Profile** - Name it whatever you want
3. **Configure Sources**: Check the displays, cameras, and audio inputs you want to use
4. **Save & Continue**: App automatically configures OBS with your selections
5. **Done!** Start recording with fully configured profiles

**Note**: You can add or modify profiles anytime via **Configure Profiles...** (Cmd+P) from the menubar.

#### Manual Source Configuration (Optional)

If you prefer to manually configure OBS sources, you can skip the wizard. However, the automated setup is recommended for the best experience.

#### Add Source Record Filters (For ISO Recordings)

**Automated setup (recommended):**
```bash
# After adding your sources in OBS, run:
./scripts/setup-source-record.sh filters
```

This automatically adds a Source Record filter to all video sources.

**Manual setup:**
For each source you want recorded separately:
1. Right-click the source > **Filters**
2. Click **+** under "Effect Filters"
3. Select **"Source Record"**
4. Set format to **MOV** or **MKV**
5. Leave file path empty (uses ~/Movies default)
6. Click **Close**

### 4. Grant Permissions
In **System Settings > Privacy & Security**, enable:
- Screen Recording: OBS
- Camera: OBS
- Microphone: OBS
- Accessibility: Terminal

### 5. Start Recording
Double-click **Tutorial Recorder.app** on your Desktop - a video icon appears in your menubar!

## Usage

### Using the Menubar App

1. Double-click **Tutorial Recorder.app** on Desktop (or from Applications)
2. A video camera icon appears in your menu bar
3. Click the icon to access controls:
   - **Start Recording...** - Enter project name and begin
   - **Stop Recording** - Stop and collect all files
   - **Sync Now** - Manually sync to Google Drive
   - **Sync Status & Activity...** - Open the sync panel (Google Drive-style interface)
   - **Transcribe Last Recording** (Cmd+T) - Manually transcribe most recent recording
   - **Auto-close OBS** - Toggle auto-close setting
   - **Auto-sync after recording** - Toggle auto-sync setting
   - **Open OBS** - Launch OBS Studio
   - **Open Recordings Folder** - Browse all projects

### Menubar Icon States

| Icon | State |
|------|-------|
| Video circle (gray) | Idle - ready to record |
| Record circle (red) | Recording in progress |
| Sync arrows (blue, animated) | Syncing to Google Drive |

### Profile Management

Tutorial Recorder supports multiple recording profiles for different hardware setups. Each profile has its own OBS configuration with specific displays, cameras, and audio sources.

#### Built-in Profiles

- **Mac Multi-Screen** - Multiple displays with external camera and microphone
- **MacBook Single** - Single built-in display with FaceTime camera and built-in microphone
- **PC 7 Cam + Mic** - Single display with 7 cameras and 7 microphones

#### Creating Custom Profiles

You can create unlimited custom profiles for different recording scenarios:

1. **From Menubar**: Click icon > **Configure Profiles...** (Cmd+P)
2. **From Start Dialog**: Click **Start Recording...** > Select **＋ Create New Profile...**
3. **Name your profile** (e.g., "Studio Setup", "Podcast Recording")
4. **Select sources**:
   - Check the displays you want to capture
   - Check the cameras to include
   - Check the audio inputs to use
5. **Click "Save Configuration"**
6. App automatically configures OBS via WebSocket

#### How Profile Configuration Works

When you save a profile:

1. **Profile Creation**: App creates the OBS profile if it doesn't exist
2. **Scene Setup**: Creates "Tutorial Recording" scene in that profile
3. **Source Clearing**: Removes any old sources to prevent conflicts
4. **Source Addition**: Adds your selected displays, cameras, and audio sources
5. **Ready to Use**: Profile is immediately available for recording

#### Switching Profiles

When you start a recording:

1. Click **Start Recording...**
2. Select your desired profile from the dropdown
3. Enter project name
4. App automatically:
   - Launches OBS (if not running)
   - Switches to the selected profile
   - Starts recording with the correct sources

#### Editing Existing Profiles

1. Open **Configure Profiles...** (Cmd+P)
2. Select the profile tab you want to edit
3. Check/uncheck sources as needed
4. Click **Save Configuration**
5. OBS is automatically reconfigured

**Note**: Source changes are applied immediately to the OBS profile.

### Recording Workflow

**Starting:**
1. Click the menubar icon
2. Select "Start Recording..."
3. Enter a project name
4. OBS launches (if not running) and recording begins
5. Icon turns red to indicate recording

**Stopping:**
1. Click the red menubar icon
2. Select "Stop Recording"
3. All ISO files are collected to your project folder
4. Project folder opens automatically

### Auto-Start on Login

To have Tutorial Recorder start automatically:
1. Open **System Settings > General > Login Items**
2. Click **+** and add **Tutorial Recorder.app**

### Transcription

The app automatically transcribes your recordings using Whisper AI, which runs 100% locally on your Mac.

#### How It Works

1. After recording stops, audio is extracted from the video
2. If auto-transcribe is enabled, Whisper processes the audio
3. Transcript is saved as `transcript.txt` in the session folder
4. A notification appears when transcription is complete

#### Configuration

Open **Preferences** (from the menubar or sync panel):

| Setting | Description |
|---------|-------------|
| Auto-transcribe recordings | Enable/disable automatic transcription after each recording |
| Transcription Model | Choose accuracy vs. speed (tiny/base/small/medium) |

#### Models

| Model | Size | Speed | Best For |
|-------|------|-------|----------|
| Tiny | 75MB | Very Fast | Quick drafts, testing |
| Base | 150MB | Fast | Good balance |
| Small | 500MB | Medium | **Recommended** - high accuracy for tutorials |
| Medium | 1.5GB | Slow | Maximum accuracy |

#### Manual Transcription

- **Menubar**: Click icon > **Transcribe Last Recording** (Cmd+T)
- **Sync Panel**: Click **Transcribe recording** in quick links

#### Command Line Setup

```bash
# Check transcription status
./scripts/setup-transcription.sh status

# Download a different model
./scripts/setup-transcription.sh medium

# Download all models
./scripts/setup-transcription.sh all
```

### Cloud Sync

The menubar app includes Google Drive sync via rclone with a native interface inspired by Google Drive's desktop app.

#### Sync Status Panel

Click **"Sync Status & Activity..."** in the menu to open the sync panel:

- **Home Tab**: Shows sync status, recording status, recent file activity, and quick actions
- **Sync Activity Tab**: View pending files, last sync output, and sync history
- **Recordings Tab**: Browse recent recording projects
- **Settings Tab**: Configure all sync and recording options

The panel shows real-time sync progress with file-by-file status, similar to Google Drive.

#### First-time Setup

1. Click the menubar icon > **Sync Status & Activity...**
2. Go to the **Settings** tab
3. Click **Configure Cloud Sync...**
4. In the configuration window:
   - If rclone is not installed, click **Install rclone**
   - If Google Drive is not configured, click **Configure rclone** (opens browser for Google authentication)
5. Set your local recordings folder (use **Browse...** to select)
6. Enter your Google Drive destination folder name
7. Enable **Auto-sync after recording stops** if desired
8. Click **Save**

#### Using Cloud Sync

| Action | How |
|--------|-----|
| Sync Now | Click menubar icon > **Sync Now** |
| View Sync Status | Click **Sync Status & Activity...** to open panel |
| Check pending files | Open panel > **Sync Activity** tab |
| Add folder to sync | Open panel > **Home** tab > **Add Folder** button |
| Toggle auto-sync | Click menubar icon > **Auto-sync after recording** |

#### Configuration Options

| Option | Description |
|--------|-------------|
| Local Recordings Folder | Path to your recordings (default: ~/Desktop/Tutorial Recordings) |
| Google Drive Folder | Destination folder name on Google Drive |
| Auto-sync after recording | Automatically sync when recording stops |
| Only sync exports | Skip raw files, only sync the exports folder |
| Additional Folders | Add extra folders to sync (e.g., project files) |

#### Animated Sync Icon

When syncing is in progress:
- The menubar icon animates (blue sync arrows)
- The sync panel shows "Syncing..." with progress
- A notification appears when sync completes

#### Command Line (Alternative)

```bash
./scripts/setup-cloud-sync.sh configure  # Interactive terminal setup
./scripts/setup-cloud-sync.sh sync       # Manual sync
./scripts/setup-cloud-sync.sh test       # Dry run
./scripts/setup-cloud-sync.sh status     # Check configuration
```

### Settings

Access settings from the menubar menu or via **Sync Status & Activity... > Settings** tab.

| Setting | Default | Description |
|---------|---------|-------------|
| Auto-close OBS after recording | OFF | When enabled, OBS closes automatically after stopping. When OFF, OBS only closes if the app launched it (not if it was already running). |
| Auto-sync after recording | OFF | When enabled, automatically uploads recordings to Google Drive after each recording session stops. |

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
    │   └── 2026-01-18 13-00-00/        # Recording session folder
    │       ├── Screen 1.mkv            # ISO from Source Record
    │       ├── Screen 2.mkv            # ISO from Source Record
    │       ├── Screen 3.mkv            # ISO from Source Record
    │       ├── Camera - ZV-E10.mkv     # ISO from Source Record
    │       ├── composite.mov           # Main composite recording
    │       ├── audio.aac               # Auto-extracted audio track
    │       └── transcript.txt          # Auto-generated transcript
    ├── exports/
    ├── session.log                     # Debug log for this session
    └── metadata.json
```

Each recording session creates a timestamped folder within `raw/`, keeping multiple recording sessions organized. Audio is automatically extracted from the composite recording and transcribed to text.

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

**Important for macOS**: The Source Record plugin must use Apple's VideoToolbox hardware encoder (encoder ID: `com.apple.videotoolbox.videoencoder.ave.avc`) instead of the default x264 software encoder. The x264 encoder causes pipe write errors and can freeze OBS. The automated setup script (`./scripts/setup-source-record.sh filters`) configures this correctly.

## Automated Profile Configuration

Tutorial Recorder fully automates OBS profile configuration via WebSocket, eliminating manual setup.

### How It Works

When you configure a profile, the app automatically:

1. **Creates/Switches Profile** - Uses `SetCurrentProfile` WebSocket command
2. **Creates Scene** - Creates "Tutorial Recording" scene via `CreateScene`
3. **Clears Old Sources** - Removes all existing scene items to prevent conflicts
4. **Adds Display Captures** - Creates `screen_capture` inputs for each selected display
5. **Adds Cameras** - Creates `av_capture_input` inputs for each selected camera
6. **Adds Audio** - Creates `coreaudio_input_capture` inputs for each audio source

### WebSocket Commands Used

| Command | Purpose |
|---------|---------|
| `GetProfileList` | List all profiles and detect current profile |
| `SetCurrentProfile` | Switch to a specific profile |
| `CreateProfile` | Create a new OBS profile |
| `CreateScene` | Create a scene in the profile |
| `SetCurrentProgramScene` | Set the active scene |
| `GetSceneItemList` | List all sources in a scene |
| `RemoveSceneItem` | Remove a source from a scene |
| `CreateInput` | Add a source with specific settings |

### Source Configuration

**Display Capture (macOS screen_capture)**:
```json
{
  "display": 0,          // 0=Display 1, 1=Display 2, etc.
  "show_cursor": true
}
```

**Camera (av_capture_input)**:
```json
{
  "device_name": "FaceTime HD Camera"
}
```

**Audio (coreaudio_input_capture)**:
```json
{
  "device_id": "Built-in Microphone"
}
```

### Profile Storage

Profile configurations are saved to:
```
~/.config/tutorial-recorder/profile-configs.json
```

Example configuration:
```json
{
  "MacBook-Single": {
    "profileName": "MacBook-Single",
    "displays": ["Display 1"],
    "cameras": ["FaceTime HD Camera"],
    "audioInputs": ["Built-in Microphone"],
    "isConfigured": true
  },
  "Mac-MultiScreen": {
    "profileName": "Mac-MultiScreen",
    "displays": ["Display 1", "Display 2", "Display 3"],
    "cameras": ["Camera - ZV-E1"],
    "audioInputs": ["Microphone - FIFINE"],
    "isConfigured": true
  }
}
```

### Smart Source Clearing

To prevent source accumulation and mismatches, the app:

1. Gets all scene items using `GetSceneItemList`
2. Removes each item individually using `RemoveSceneItem`
3. Logs each removal for debugging
4. Then adds the new configured sources

This ensures each profile has exactly the sources you configured, with no leftover sources from previous configurations.

## Playing and Editing Recordings

### Playing MKV Files

The ISO recordings are saved as MKV files. Install VLC to play them:

```bash
brew install --cask vlc
```

Or download from: https://www.videolan.org/vlc/

### Extracting Audio

The microphone audio is embedded in all video recordings. To extract just the audio:

```bash
# Extract audio from any recording
ffmpeg -i "Screen 1.mkv" -vn -acodec copy "audio.aac"

# Convert to MP3
ffmpeg -i "Screen 1.mkv" -vn -acodec mp3 "audio.mp3"
```

### Converting MKV to MP4

```bash
# Remux without re-encoding (fast)
ffmpeg -i "Screen 1.mkv" -c copy "Screen 1.mp4"
```

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

**Note**: After OBS launches, the WebSocket server may take a few seconds to initialize. If connections fail intermittently right after OBS starts, wait a moment and try again.

### Recording Doesn't Start

**Solutions**:
1. Check OBS has sources configured
2. Verify no permission dialogs are blocking OBS
3. Check OBS Output settings are valid

### Source Record Files Not Created

**Symptoms**: Recording works but no separate ISO files appear in ~/Movies

**Common Cause**: The default x264 encoder causes "pipe write errors" on macOS, preventing Source Record from saving files. OBS may also freeze.

**Solution**: Use Apple's VideoToolbox hardware encoder instead:

```bash
# Run this to reconfigure all Source Record filters with the correct encoder:
./scripts/setup-source-record.sh filters
```

Or manually configure each filter:
1. Right-click source > **Filters**
2. Click on the **Source Record** filter
3. Set **Encoder** to `Apple VT H264 Hardware Encoder`
4. Set **Recording Format** to `Matroska Video (.mkv)` or `MOV`
5. Click **Close**

**Note**: After changing encoder settings, restart OBS for changes to take full effect.

### Source Record Files Not Collected

**Symptoms**: ISO files are created in ~/Movies but not moved to project folder

**Solutions**:
1. Verify Source Record filter is added to each source
2. Check ~/Movies for the files manually
3. Ensure files have finished writing before stopping
4. Check that the stop script has permission to move files

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

### OBS Freezes or Hangs

**Symptoms**: OBS shows spinning wheel when starting recording

**Cause**: Source Record plugin using incompatible encoder

**Solution**: Reconfigure Source Record filters with Apple VideoToolbox encoder:
```bash
./scripts/setup-source-record.sh filters
```

This sets the correct encoder (`com.apple.videotoolbox.videoencoder.ave.avc`) which is stable on macOS. The default x264 encoder causes pipe write errors.

## Debugging & Logs

The app generates log files for debugging issues:

### Log Locations

| Log File | Location | Purpose |
|----------|----------|---------|
| Session log | `<project>/session.log` | Per-recording session details |
| App log | `~/.config/tutorial-recorder/app.log` | Global app activity |
| OBS log | `~/Library/Application Support/obs-studio/logs/` | OBS internal logs |

### Viewing Logs

```bash
# View current session log (while recording)
cat ~/Desktop/Tutorial\ Recordings/*/session.log | tail -50

# View app log
cat ~/.config/tutorial-recorder/app.log | tail -50

# View latest OBS log
cat ~/Library/Application\ Support/obs-studio/logs/*.txt | tail -100
```

### Common Log Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Encoder ID not found` | Wrong encoder configured | Run `./scripts/setup-source-record.sh filters` |
| `os_process_pipe_write failed` | x264 encoder issue | Switch to Apple VT encoder |
| `Could not connect to OBS WebSocket` | WebSocket not enabled/ready | Enable in OBS, wait for startup |

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `install.sh` | Complete installer (run from repo root) |
| `scripts/start-tutorial.sh` | Start new recording session |
| `scripts/stop-tutorial.sh` | Stop recording and collect ISO files |
| `scripts/toggle-recording.sh` | Combined start/stop |
| `scripts/setup-source-record.sh` | Install Source Record plugin and add filters |
| `scripts/setup-cloud-sync.sh` | Configure rclone for Google Drive backup |
| `scripts/setup-transcription.sh` | Install whisper-cpp and download models |
| `scripts/setup-sources.sh` | Add sources to OBS via WebSocket |
| `scripts/obs-websocket.sh` | WebSocket helper functions |

## App Architecture

The menubar app is built with Swift/Cocoa and organized into modular components:

```
TutorialRecorder/
├── Sources/
│   ├── main.swift                      # App entry point
│   ├── AppDelegate.swift               # Main app controller, menu, icon animation
│   ├── RecordingManager.swift          # OBS recording control via WebSocket
│   ├── OBSSourceManager.swift          # OBS profile and source configuration
│   ├── SyncManager.swift               # Cloud sync logic, rclone integration
│   ├── TranscriptionManager.swift      # Whisper transcription integration
│   ├── Utils.swift                     # Logging, shell commands, path utilities
│   └── Windows/
│       ├── MainPanel.swift             # Google Drive-style sync panel
│       ├── SyncConfigWindow.swift      # Sync/transcription configuration
│       ├── SyncStatusWindow.swift      # Detailed sync status
│       ├── ProgressWindow.swift        # Progress indicator (always on top)
│       ├── ProfileSetupWindow.swift    # Profile configuration interface
│       └── FirstTimeSetupWizard.swift  # Multi-step first-time setup wizard
├── build.sh                            # Build script
├── AppIcon.icns                        # App icon
└── AppIcon.iconset/                    # Icon source files
```

### Building from Source

```bash
cd TutorialRecorder
./build.sh
```

The build script compiles all Swift files and creates the app bundle at `~/Desktop/Tutorial Recorder.app`.

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

---

## Coming Soon: Live Recording Assistant

**Powered by PersonaPlex Full Duplex AI**

Transform your tutorial recordings with natural voice interaction. Instead of clicking buttons to start, stop, and manage recordings, simply have a conversation with your recording assistant.

### Current Experience
```
Click menubar → Select profile → Enter name → Click start → Record → Click stop
```

### With PersonaPlex
```
You: "Start recording the authentication tutorial"
Assistant: "Got it, starting recording for authentication tutorial..."

[Recording in progress]

You: "Add a marker here for the login section"
Assistant: "Marker added at 2:45 for login section"

You: "Stop recording and add a note about the password reset"
Assistant: "Stopped. I've added a note about password reset to the metadata."
```

### Features

| Feature | Description |
|---------|-------------|
| **Voice Commands** | Start, stop, pause, mark sections with natural speech |
| **Back-channeling** | Verbal confirmations without interrupting your flow |
| **Smart Markers** | Add chapter markers and notes by voice during recording |
| **Session Context** | AI remembers what you're recording and suggests profile |
| **Hands-Free Control** | Perfect for tutorials where your hands are on the keyboard |

### Technical Requirements

- 24GB+ VRAM (Mac M2 Pro or higher)
- 32GB RAM recommended
- Runs 100% locally - no cloud required
- <500ms response time

## License

MIT License - See LICENSE file for details.
