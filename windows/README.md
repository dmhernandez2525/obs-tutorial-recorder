# OBS Tutorial Recorder - Windows

A Windows application for automating OBS Studio recordings with ISO (individual source) recording support. Perfect for multi-camera setups with up to 6 cameras and 6 mics (OBS supports max 6 audio tracks).

## Quick Setup

### One-Command Setup

```bash
cd obs-tutorial-recorder/windows
python setup.py
```

Or just double-click **`SETUP.bat`**

This will:
1. Install all Python dependencies
2. Download and install the Source Record plugin
3. Create the desktop shortcut
4. Set up configuration directories

### Prerequisites

1. **Python 3.10+**: [Download Python](https://python.org)
2. **OBS Studio**: [Download OBS](https://obsproject.com/download)

## Features

- **Taskbar Application**: Shows in taskbar like OBS
- **Multi-Camera Support**: Record up to 6 cameras and 6 mics with separate ISO files
- **ISO Recording**: Each source records to a separate file
- **Profile Management**: Save and switch between recording configurations
- **Automatic OBS Control**: Launches OBS, configures profiles, starts/stops recording
- **Smart File Organization**: Automatic folder structure with timestamps

## Usage

1. **Run the app**: Double-click `Tutorial Recorder` on your Desktop
2. **Ensure OBS is running** with WebSocket enabled (see below)
3. **Select a profile** (PC-Single or PC-6CamMic)
4. **Enter a project name**
5. **Click Start Recording**

### OBS WebSocket Setup (Required)

1. Open OBS Studio
2. Go to **Tools → WebSocket Server Settings**
3. Check **Enable WebSocket Server**
4. Uncheck **Enable Authentication**
5. Port should be **4455** (default)

## Output Structure

```
C:\Users\{user}\Desktop\Tutorial Recordings\
└── 2026-01-27_my-project\
    ├── raw\
    │   └── 2026-01-27 14-30-45\
    │       ├── Display_1.mkv
    │       ├── Camera_1.mkv
    │       ├── Camera_2.mkv
    │       └── ...
    ├── exports\
    ├── metadata.json
    └── session.log
```

## Manual Installation

If the setup script doesn't work:

### 1. Install Python Dependencies

```bash
pip install websockets pystray Pillow customtkinter pywin32 psutil plyer
```

### 2. Install Source Record Plugin

1. Download from [OBS Forums](https://obsproject.com/forum/resources/source-record.1285/)
2. Extract to `%APPDATA%\obs-studio\plugins\`
3. Restart OBS

### 3. Install FFmpeg (Optional)

```bash
winget install FFmpeg
```

## Configuration

All settings are stored in:
```
%APPDATA%\TutorialRecorder\
├── profile-configs.json
├── sync-config.json
└── app.log
```

## Troubleshooting

### App doesn't start
- Run `Tutorial Recorder.bat` to see error messages
- Check Python is installed: `python --version`

### OBS connection fails
- Ensure OBS is running
- Check WebSocket is enabled (Tools → WebSocket Server Settings)
- Verify port 4455 is not blocked

### Cameras not detected
- Ensure cameras work in OBS directly first
- Click "Configure Profiles" to refresh device list

### ISO files not created
- Ensure Source Record plugin is installed
- Check OBS logs for plugin errors

## Development

### Project Structure

```
windows/
├── SETUP.bat              # Double-click to install
├── setup.py               # Automated setup script
├── run.py                 # Application entry point
├── requirements.txt       # Python dependencies
├── resources/
│   ├── icon.ico
│   └── icon_recording.ico
└── src/
    ├── app.py             # Main application controller
    ├── core/
    │   ├── obs_websocket.py
    │   ├── obs_source_manager.py
    │   ├── recording_manager.py
    │   └── device_enumerator.py
    ├── ui/
    │   ├── main_window.py
    │   ├── profile_setup.py
    │   └── progress_dialog.py
    └── utils/
        ├── paths.py
        ├── config.py
        └── logger.py
```

### Running from Source

```bash
cd windows
python run.py
```

## License

Same license as the parent OBS Tutorial Recorder project.
