#!/usr/bin/env python3
"""
OBS Tutorial Recorder - Windows Setup Script
Run this once to install all dependencies and configure the application.

Usage:
    python setup.py
"""

import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
from pathlib import Path


def print_header(text):
    print("\n" + "=" * 60)
    print(f"  {text}")
    print("=" * 60)


def print_step(text):
    print(f"\n>> {text}")


def print_success(text):
    print(f"   [OK] {text}")


def print_warning(text):
    print(f"   [WARNING] {text}")


def print_error(text):
    print(f"   [ERROR] {text}")


def run_command(cmd, check=True):
    """Run a command and return success status."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if check and result.returncode != 0:
            print_error(f"Command failed: {cmd}")
            print(result.stderr)
            return False
        return True
    except Exception as e:
        print_error(f"Command error: {e}")
        return False


def check_python():
    """Check Python version."""
    print_step("Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 10:
        print_success(f"Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print_error(f"Python 3.10+ required, found {version.major}.{version.minor}")
        return False


def install_dependencies():
    """Install Python dependencies."""
    print_step("Installing Python dependencies...")

    requirements = Path(__file__).parent / "requirements.txt"
    if not requirements.exists():
        print_error("requirements.txt not found")
        return False

    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "-r", str(requirements)],
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        print_success("All dependencies installed")
        return True
    else:
        print_error("Failed to install dependencies")
        print(result.stderr)
        return False


def check_obs_installed():
    """Check if OBS Studio is installed."""
    print_step("Checking OBS Studio installation...")

    obs_paths = [
        Path(r"C:\Program Files\obs-studio\bin\64bit\obs64.exe"),
        Path(r"C:\Program Files (x86)\obs-studio\bin\64bit\obs64.exe"),
        Path.home() / "AppData" / "Local" / "Programs" / "obs-studio" / "bin" / "64bit" / "obs64.exe",
    ]

    for path in obs_paths:
        if path.exists():
            print_success(f"OBS found at: {path.parent.parent.parent}")
            return path

    print_error("OBS Studio not found")
    print("   Please install OBS Studio from: https://obsproject.com/download")
    return None


def install_source_record_plugin():
    """Download and install the Source Record plugin."""
    print_step("Installing Source Record plugin...")

    # Check if already installed - multiple possible locations
    plugin_locations = [
        Path(r"C:\Program Files\obs-studio\obs-plugins\64bit\source-record.dll"),
        Path(r"C:\Program Files\obs-studio\data\obs-plugins\source-record"),
        Path.home() / "AppData" / "Roaming" / "obs-studio" / "plugins" / "source-record" / "bin" / "64bit" / "source-record.dll",
        Path.home() / "AppData" / "Roaming" / "obs-studio" / "plugins" / "source-record",
    ]

    for loc in plugin_locations:
        if loc.exists():
            print_success(f"Source Record plugin already installed at: {loc}")
            return True

    # Download from OBS Forums - this is the official distribution channel
    # File ID 113212 is the Windows portable version with proper obs-plugins structure
    # Note: Version number in URL (6239) may need updating for future versions
    download_url = "https://obsproject.com/forum/resources/source-record.1285/version/6239/download?file=113212"
    download_path = Path.home() / "Downloads" / "source-record.zip"

    print("   Downloading Source Record plugin from OBS Forums...")
    try:
        import ssl
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }
        req = urllib.request.Request(download_url, headers=headers)
        ctx = ssl.create_default_context()

        with urllib.request.urlopen(req, context=ctx) as response:
            with open(download_path, 'wb') as f:
                f.write(response.read())
        print_success("Downloaded plugin v0.4.6")
    except Exception as e:
        print_warning(f"Could not download plugin: {e}")
        print("   Please manually install from: https://obsproject.com/forum/resources/source-record.1285/")
        print("   1. Download the Windows version from the link above")
        print("   2. Extract to: %APPDATA%\\obs-studio\\")
        print("   3. Restart OBS Studio")
        return False

    # Extract to temp, then move to correct OBS 28+ plugin location
    import tempfile
    temp_dir = Path(tempfile.mkdtemp())

    print("   Extracting plugin...")
    try:
        with zipfile.ZipFile(download_path, 'r') as zip_ref:
            zip_contents = zip_ref.namelist()
            print(f"   Zip contains: {len(zip_contents)} files")
            zip_ref.extractall(temp_dir)

        # OBS 28+ expects plugins in: plugins/{name}/bin/64bit/{name}.dll
        plugin_dir = Path.home() / "AppData" / "Roaming" / "obs-studio" / "plugins" / "source-record"
        bin_dir = plugin_dir / "bin" / "64bit"
        data_dir = plugin_dir / "data"

        bin_dir.mkdir(parents=True, exist_ok=True)
        data_dir.mkdir(parents=True, exist_ok=True)

        # Move DLL from extracted obs-plugins/64bit/
        src_dll = temp_dir / "obs-plugins" / "64bit" / "source-record.dll"
        if src_dll.exists():
            shutil.copy2(src_dll, bin_dir / "source-record.dll")
            print_success(f"DLL installed to: {bin_dir}")

        # Move data from extracted data/obs-plugins/source-record/
        src_data = temp_dir / "data" / "obs-plugins" / "source-record"
        if src_data.exists():
            for item in src_data.iterdir():
                dest = data_dir / item.name
                if item.is_dir():
                    if dest.exists():
                        shutil.rmtree(dest)
                    shutil.copytree(item, dest)
                else:
                    shutil.copy2(item, dest)
            print_success(f"Data installed to: {data_dir}")

        # Clean up
        download_path.unlink()
        shutil.rmtree(temp_dir)

        # Verify installation
        final_dll = bin_dir / "source-record.dll"
        if final_dll.exists():
            print_success("Plugin installation verified")
            print(f"   Location: {plugin_dir}")
        else:
            print_warning("Plugin may not have installed correctly")

        return True
    except Exception as e:
        print_error(f"Failed to extract plugin: {e}")
        import traceback
        traceback.print_exc()
        return False


def check_obs_websocket():
    """Check if OBS WebSocket is likely enabled."""
    print_step("Checking OBS WebSocket configuration...")
    print_warning("Cannot automatically verify WebSocket settings")
    print("   Please ensure in OBS:")
    print("   1. Go to Tools > WebSocket Server Settings")
    print("   2. Enable 'Enable WebSocket Server'")
    print("   3. Disable 'Enable Authentication' (for local use)")
    print("   4. Port should be 4455")
    return True


def create_icons():
    """Create application icons."""
    print_step("Creating application icons...")

    try:
        from PIL import Image, ImageDraw

        resources_dir = Path(__file__).parent / "resources"
        resources_dir.mkdir(exist_ok=True)

        def create_icon(size=256, recording=False):
            img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)

            # Background circle
            padding = size // 16
            draw.ellipse(
                [padding, padding, size - padding, size - padding],
                fill=(64, 64, 64, 255),
                outline=(48, 48, 48, 255),
                width=2
            )

            # Inner red circle
            inner_padding = size // 4
            color = (220, 53, 69, 255) if recording else (150, 150, 150, 255)
            draw.ellipse(
                [inner_padding, inner_padding, size - inner_padding, size - inner_padding],
                fill=color,
                outline=(180, 40, 50, 255) if recording else (100, 100, 100, 255),
                width=2
            )

            # White center
            center_padding = size // 3
            draw.ellipse(
                [center_padding, center_padding, size - center_padding, size - center_padding],
                fill=(255, 255, 255, 200)
            )

            return img

        # Create icons at multiple sizes
        sizes = [16, 32, 48, 64, 128, 256]

        # Normal icon
        icons = [create_icon(s, False) for s in sizes]
        ico_path = resources_dir / "icon.ico"
        icons[0].save(ico_path, format='ICO', sizes=[(s, s) for s in sizes], append_images=icons[1:])
        print_success(f"Created: {ico_path.name}")

        # Recording icon
        rec_icons = [create_icon(s, True) for s in sizes]
        rec_ico_path = resources_dir / "icon_recording.ico"
        rec_icons[0].save(rec_ico_path, format='ICO', sizes=[(s, s) for s in sizes], append_images=rec_icons[1:])
        print_success(f"Created: {rec_ico_path.name}")

        return True
    except ImportError:
        print_warning("Pillow not yet installed, icons will be created on first run")
        return True
    except Exception as e:
        print_warning(f"Could not create icons: {e}")
        return True


def create_desktop_shortcut():
    """Create desktop shortcut."""
    print_step("Creating desktop shortcut...")

    desktop = Path.home() / "Desktop"
    shortcut_path = desktop / "Tutorial Recorder.bat"

    python_exe = sys.executable
    script_dir = Path(__file__).parent
    run_script = script_dir / "run.py"

    # Create batch file
    batch_content = f'''@echo off
title Tutorial Recorder
cd /d "{script_dir}"
"{python_exe}" "{run_script}"
if errorlevel 1 pause
'''

    try:
        with open(shortcut_path, 'w') as f:
            f.write(batch_content)
        print_success(f"Created: {shortcut_path}")
        return True
    except Exception as e:
        print_error(f"Failed to create shortcut: {e}")
        return False


def create_config_directories():
    """Create configuration directories."""
    print_step("Creating configuration directories...")

    dirs = [
        Path.home() / "AppData" / "Roaming" / "TutorialRecorder",
        Path.home() / "AppData" / "Local" / "TutorialRecorder",
        Path.home() / "Desktop" / "Tutorial Recordings",
    ]

    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
        print_success(f"Created: {d}")

    return True


def check_ffmpeg():
    """Check if FFmpeg is installed."""
    print_step("Checking FFmpeg installation...")

    try:
        result = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
        if result.returncode == 0:
            version_line = result.stdout.split('\n')[0]
            print_success(f"FFmpeg found: {version_line[:50]}...")
            return True
    except FileNotFoundError:
        pass

    print_warning("FFmpeg not found (optional - needed for audio extraction)")
    print("   Install with: winget install FFmpeg")
    return True  # Not critical


def main():
    print_header("OBS Tutorial Recorder - Windows Setup")
    print("\nThis script will set up everything you need to run Tutorial Recorder.")

    all_ok = True

    # Check Python
    if not check_python():
        print_error("Setup cannot continue without Python 3.10+")
        return False

    # Install Python dependencies
    if not install_dependencies():
        all_ok = False

    # Check OBS
    obs_path = check_obs_installed()
    if not obs_path:
        all_ok = False

    # Install Source Record plugin
    if obs_path:
        install_source_record_plugin()

    # Check WebSocket
    check_obs_websocket()

    # Create icons
    create_icons()

    # Create config directories
    create_config_directories()

    # Create desktop shortcut
    create_desktop_shortcut()

    # Check FFmpeg
    check_ffmpeg()

    # Summary
    print_header("Setup Complete!")

    if all_ok:
        print("\nYou can now:")
        print("  1. Double-click 'Tutorial Recorder' on your Desktop")
        print("  2. Make sure OBS is running with WebSocket enabled")
        print("  3. Configure your profiles in the app")
        print("  4. Start recording!")
    else:
        print("\nSetup completed with some warnings. Please review the messages above.")

    print("\n" + "=" * 60)
    input("\nPress Enter to exit...")
    return all_ok


if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except Exception as e:
        print_error(f"Setup failed: {e}")
        import traceback
        traceback.print_exc()
        input("\nPress Enter to exit...")
        sys.exit(1)
