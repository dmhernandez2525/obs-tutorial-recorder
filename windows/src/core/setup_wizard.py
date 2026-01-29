"""
Setup Wizard for OBS Tutorial Recorder.
Handles first-run setup including:
- ffmpeg installation
- Source Record plugin installation
- OBS WebSocket verification
"""

import json
import os
import shutil
import socket
import subprocess
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional, Tuple
from urllib.request import urlopen, Request
from urllib.error import URLError

from ..utils.paths import (
    get_config_dir,
    get_obs_path,
    get_obs_user_plugin_path,
    get_source_record_plugin_path,
    ensure_dir,
)
from ..utils.logger import log_info, log_error, log_warning, log_debug, log_success


# Download URLs
FFMPEG_URL = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
SOURCE_RECORD_URL = "https://github.com/exeldro/obs-source-record/releases/latest/download/source-record-0.4.1-windows-x64.zip"

# Fallback Source Record URL (in case latest changes)
SOURCE_RECORD_FALLBACK_URLS = [
    "https://github.com/exeldro/obs-source-record/releases/download/0.4.1/source-record-0.4.1-windows-x64.zip",
    "https://github.com/exeldro/obs-source-record/releases/download/0.4.0/source-record-0.4.0-windows-x64.zip",
]


@dataclass
class SetupStatus:
    """Status of each setup component."""
    obs_installed: bool = False
    obs_websocket_enabled: bool = False
    ffmpeg_installed: bool = False
    source_record_installed: bool = False

    @property
    def all_ready(self) -> bool:
        """Check if all components are ready."""
        return (
            self.obs_installed and
            self.obs_websocket_enabled and
            self.ffmpeg_installed and
            self.source_record_installed
        )

    @property
    def can_record(self) -> bool:
        """Check if basic recording is possible (ISO may not work)."""
        return self.obs_installed and self.obs_websocket_enabled


class SetupWizard:
    """
    Handles first-run setup and prerequisite installation.
    """

    def __init__(self):
        self._setup_complete_file = get_config_dir() / "setup_complete.json"
        self._status = SetupStatus()

    def is_first_run(self) -> bool:
        """Check if this is the first run (setup not complete)."""
        return not self._setup_complete_file.exists()

    def mark_setup_complete(self):
        """Mark setup as complete."""
        ensure_dir(get_config_dir())
        with open(self._setup_complete_file, 'w') as f:
            json.dump({
                "setup_complete": True,
                "ffmpeg_installed": self._status.ffmpeg_installed,
                "source_record_installed": self._status.source_record_installed,
            }, f, indent=2)
        log_info("Setup marked as complete")

    def check_all(self, on_progress: Optional[Callable[[str], None]] = None) -> SetupStatus:
        """
        Check status of all prerequisites.
        Returns SetupStatus with current state.
        """
        def progress(msg: str):
            log_debug(f"[Setup] {msg}")
            if on_progress:
                on_progress(msg)

        progress("Checking OBS installation...")
        self._status.obs_installed = self._check_obs_installed()

        progress("Checking OBS WebSocket...")
        self._status.obs_websocket_enabled = self._check_websocket_enabled()

        progress("Checking ffmpeg...")
        self._status.ffmpeg_installed = self._check_ffmpeg_installed()

        progress("Checking Source Record plugin...")
        self._status.source_record_installed = self._check_source_record_installed()

        return self._status

    @property
    def status(self) -> SetupStatus:
        """Get current setup status."""
        return self._status

    # =========================================================================
    # CHECK FUNCTIONS
    # =========================================================================

    def _check_obs_installed(self) -> bool:
        """Check if OBS is installed."""
        obs_path = get_obs_path()
        if obs_path.exists():
            log_info(f"OBS found at: {obs_path}")
            return True
        log_warning("OBS not found")
        return False

    def _check_websocket_enabled(self) -> bool:
        """Check if OBS WebSocket is enabled (by checking if port is open when OBS runs)."""
        # First check if OBS is running
        import psutil
        obs_running = False
        for proc in psutil.process_iter(['name']):
            try:
                if proc.info['name'] and 'obs' in proc.info['name'].lower():
                    obs_running = True
                    break
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        if not obs_running:
            # Can't verify WebSocket if OBS isn't running
            # Assume it's enabled if setup was previously complete
            if self._setup_complete_file.exists():
                return True
            return False

        # OBS is running, check if WebSocket port is open
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', 4455))
            sock.close()
            if result == 0:
                log_info("OBS WebSocket is enabled (port 4455 open)")
                return True
            log_warning("OBS WebSocket port 4455 not open")
            return False
        except Exception as e:
            log_warning(f"Could not check WebSocket: {e}")
            return False

    def _check_ffmpeg_installed(self) -> bool:
        """Check if ffmpeg is installed and accessible."""
        # Check PATH
        try:
            result = subprocess.run(
                ['ffmpeg', '-version'],
                capture_output=True,
                timeout=5,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            if result.returncode == 0:
                log_info("ffmpeg found in PATH")
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

        # Check common install location
        ffmpeg_path = Path('C:/ffmpeg/ffmpeg.exe')
        if ffmpeg_path.exists():
            log_info(f"ffmpeg found at: {ffmpeg_path}")
            return True

        # Check bin subdirectory
        ffmpeg_bin = Path('C:/ffmpeg/bin/ffmpeg.exe')
        if ffmpeg_bin.exists():
            log_info(f"ffmpeg found at: {ffmpeg_bin}")
            return True

        log_warning("ffmpeg not found")
        return False

    def _check_source_record_installed(self) -> bool:
        """Check if Source Record plugin is installed."""
        plugin_path = get_source_record_plugin_path()
        if plugin_path.exists():
            log_info(f"Source Record plugin found at: {plugin_path}")
            return True
        log_warning("Source Record plugin not found")
        return False

    # =========================================================================
    # INSTALL FUNCTIONS
    # =========================================================================

    def install_ffmpeg(
        self,
        on_progress: Optional[Callable[[str, int], None]] = None
    ) -> Tuple[bool, str]:
        """
        Download and install ffmpeg.
        on_progress receives (message, percent_complete).
        Returns (success, message).
        """
        def progress(msg: str, pct: int = -1):
            log_info(f"[ffmpeg] {msg}")
            if on_progress:
                on_progress(msg, pct)

        progress("Downloading ffmpeg...", 0)

        try:
            # Create temp directory
            temp_dir = Path(tempfile.mkdtemp(prefix="ffmpeg_"))
            zip_path = temp_dir / "ffmpeg.zip"

            # Download with progress
            progress("Connecting to download server...", 5)

            req = Request(FFMPEG_URL, headers={'User-Agent': 'TutorialRecorder/1.0'})

            try:
                response = urlopen(req, timeout=60)
                total_size = int(response.headers.get('Content-Length', 0))
            except URLError as e:
                return False, f"Failed to connect: {e}"

            downloaded = 0
            chunk_size = 1024 * 1024  # 1MB chunks

            progress("Downloading ffmpeg (~80MB)...", 10)

            with open(zip_path, 'wb') as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        pct = int(10 + (downloaded / total_size) * 50)  # 10-60%
                        progress(f"Downloading... {downloaded // (1024*1024)}MB", pct)

            progress("Extracting ffmpeg...", 65)

            # Extract zip
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(temp_dir)

            progress("Installing ffmpeg...", 75)

            # Find the extracted folder (ffmpeg-X.X-essentials_build)
            extracted_dirs = [d for d in temp_dir.iterdir() if d.is_dir() and 'ffmpeg' in d.name.lower()]
            if not extracted_dirs:
                return False, "Could not find ffmpeg in extracted files"

            ffmpeg_src = extracted_dirs[0] / "bin"
            ffmpeg_dest = Path("C:/ffmpeg")

            # Create destination and copy files
            ensure_dir(ffmpeg_dest)

            for exe in ['ffmpeg.exe', 'ffprobe.exe', 'ffplay.exe']:
                src_file = ffmpeg_src / exe
                if src_file.exists():
                    shutil.copy2(src_file, ffmpeg_dest / exe)
                    progress(f"Installed {exe}", 80)

            progress("Adding to PATH...", 90)

            # Add to user PATH (doesn't require admin)
            self._add_to_user_path("C:\\ffmpeg")

            # Cleanup
            progress("Cleaning up...", 95)
            try:
                shutil.rmtree(temp_dir)
            except Exception:
                pass

            progress("ffmpeg installed successfully!", 100)
            self._status.ffmpeg_installed = True
            return True, "ffmpeg installed to C:\\ffmpeg"

        except Exception as e:
            log_error(f"ffmpeg installation failed: {e}")
            return False, f"Installation failed: {e}"

    def install_source_record(
        self,
        on_progress: Optional[Callable[[str, int], None]] = None
    ) -> Tuple[bool, str]:
        """
        Download and install Source Record plugin.
        Returns (success, message).
        """
        def progress(msg: str, pct: int = -1):
            log_info(f"[SourceRecord] {msg}")
            if on_progress:
                on_progress(msg, pct)

        progress("Downloading Source Record plugin...", 0)

        # Try main URL first, then fallbacks
        urls_to_try = [SOURCE_RECORD_URL] + SOURCE_RECORD_FALLBACK_URLS

        for url in urls_to_try:
            try:
                temp_dir = Path(tempfile.mkdtemp(prefix="source_record_"))
                zip_path = temp_dir / "source-record.zip"

                progress(f"Connecting...", 5)

                req = Request(url, headers={'User-Agent': 'TutorialRecorder/1.0'})

                try:
                    response = urlopen(req, timeout=30)
                except URLError:
                    log_debug(f"URL failed, trying next: {url}")
                    continue

                progress("Downloading plugin...", 20)

                with open(zip_path, 'wb') as f:
                    f.write(response.read())

                progress("Extracting plugin...", 50)

                # Extract zip
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(temp_dir)

                progress("Installing plugin...", 70)

                # Find the DLL in extracted files
                # Structure is usually: source-record/obs-plugins/64bit/source-record.dll
                # Or: obs-plugins/64bit/source-record.dll
                dll_found = False
                for root, dirs, files in os.walk(temp_dir):
                    if 'source-record.dll' in files:
                        src_dll = Path(root) / 'source-record.dll'

                        # Install to OBS 28+ plugin format
                        # %APPDATA%/obs-studio/plugins/source-record/bin/64bit/
                        dest_dir = get_obs_user_plugin_path("source-record").parent
                        ensure_dir(dest_dir)

                        dest_path = dest_dir / "source-record.dll"
                        shutil.copy2(src_dll, dest_path)

                        log_info(f"Installed Source Record to: {dest_path}")
                        dll_found = True
                        break

                if not dll_found:
                    # Try to find it differently
                    for item in temp_dir.rglob("*.dll"):
                        if "source-record" in item.name.lower():
                            dest_dir = get_obs_user_plugin_path("source-record").parent
                            ensure_dir(dest_dir)
                            shutil.copy2(item, dest_dir / "source-record.dll")
                            dll_found = True
                            break

                if not dll_found:
                    progress("Could not find plugin DLL", 0)
                    continue

                # Cleanup
                progress("Cleaning up...", 90)
                try:
                    shutil.rmtree(temp_dir)
                except Exception:
                    pass

                progress("Source Record plugin installed!", 100)
                self._status.source_record_installed = True
                return True, "Source Record plugin installed. Restart OBS to load it."

            except Exception as e:
                log_warning(f"Failed with URL {url}: {e}")
                continue

        return False, "Failed to download Source Record plugin from all sources"

    def _add_to_user_path(self, new_path: str):
        """Add a directory to the user's PATH environment variable."""
        try:
            import winreg

            # Open user environment key
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Environment",
                0,
                winreg.KEY_ALL_ACCESS
            )

            try:
                # Get current PATH
                current_path, _ = winreg.QueryValueEx(key, "Path")
            except WindowsError:
                current_path = ""

            # Check if already in PATH
            paths = current_path.split(';')
            if new_path.lower() not in [p.lower() for p in paths]:
                # Add new path
                if current_path:
                    new_value = f"{current_path};{new_path}"
                else:
                    new_value = new_path

                winreg.SetValueEx(key, "Path", 0, winreg.REG_EXPAND_SZ, new_value)
                log_info(f"Added {new_path} to user PATH")

                # Broadcast environment change
                try:
                    import ctypes
                    HWND_BROADCAST = 0xFFFF
                    WM_SETTINGCHANGE = 0x001A
                    ctypes.windll.user32.SendMessageW(
                        HWND_BROADCAST, WM_SETTINGCHANGE, 0, "Environment"
                    )
                except Exception:
                    pass
            else:
                log_debug(f"{new_path} already in PATH")

            winreg.CloseKey(key)

        except Exception as e:
            log_warning(f"Could not add to PATH: {e}")

    # =========================================================================
    # WEBSOCKET SETUP HELPER
    # =========================================================================

    def get_websocket_instructions(self) -> str:
        """Get instructions for enabling OBS WebSocket."""
        return """To enable WebSocket in OBS Studio:

1. Open OBS Studio
2. Go to Tools → WebSocket Server Settings
3. Check "Enable WebSocket Server"
4. Uncheck "Enable Authentication" (or set a password)
5. Make sure Port is 4455 (default)
6. Click OK

The WebSocket server allows this app to control OBS for recording."""

    def open_obs_for_websocket_setup(self) -> bool:
        """Launch OBS so user can enable WebSocket."""
        obs_path = get_obs_path()
        if not obs_path.exists():
            return False

        try:
            subprocess.Popen(
                [str(obs_path)],
                cwd=str(obs_path.parent),
                creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
            )
            log_info("Launched OBS for WebSocket setup")
            return True
        except Exception as e:
            log_error(f"Failed to launch OBS: {e}")
            return False


# Global instance
_setup_wizard: Optional[SetupWizard] = None


def get_setup_wizard() -> SetupWizard:
    """Get the global setup wizard instance."""
    global _setup_wizard
    if _setup_wizard is None:
        _setup_wizard = SetupWizard()
    return _setup_wizard
