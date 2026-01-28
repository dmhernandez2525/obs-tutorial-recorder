"""
Recording Manager for Windows.
Handles the complete recording lifecycle.
"""

import json
import os
import re
import shutil
import socket
import subprocess
import time
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Callable, Dict, List, Optional

import psutil

from .obs_websocket import OBSWebSocketSync
from .obs_source_manager import OBSSourceManager, DEFAULT_SCENE_NAME
from .transcription import get_transcription_manager
from ..utils.config import ProfileConfiguration, get_config_manager
from ..utils.paths import (
    get_recordings_base,
    get_videos_dir,
    get_obs_path,
    get_project_path,
    get_session_dir,
    ensure_dir,
)
from ..utils.logger import (
    log_info,
    log_error,
    log_warning,
    log_success,
    log_debug,
    set_session_log,
    clear_session_log,
)


class RecordingState(Enum):
    """Recording state machine states."""
    IDLE = "idle"
    STARTING = "starting"
    RECORDING = "recording"
    STOPPING = "stopping"


@dataclass
class SessionInfo:
    """Information about the current recording session."""
    project_name: str
    project_path: Path
    session_path: Path
    profile_name: str
    scene_name: str  # Added: track scene name separately
    start_time: datetime = field(default_factory=datetime.now)
    raw_dir: Path = field(init=False)
    exports_dir: Path = field(init=False)

    def __post_init__(self):
        self.raw_dir = self.project_path / "raw"
        self.exports_dir = self.project_path / "exports"


class RecordingManager:
    """
    Manages the complete recording lifecycle.
    State machine: IDLE -> STARTING -> RECORDING -> STOPPING -> IDLE
    """

    def __init__(self):
        self._state = RecordingState.IDLE
        self._session: Optional[SessionInfo] = None
        self._ws: Optional[OBSWebSocketSync] = None
        self._source_manager: Optional[OBSSourceManager] = None
        self._state_callbacks: List[Callable[[RecordingState], None]] = []
        self._config_manager = get_config_manager()
        self._last_error: Optional[str] = None

    @property
    def state(self) -> RecordingState:
        return self._state

    @property
    def is_recording(self) -> bool:
        return self._state == RecordingState.RECORDING

    @property
    def is_busy(self) -> bool:
        return self._state in (RecordingState.STARTING, RecordingState.STOPPING)

    @property
    def session(self) -> Optional[SessionInfo]:
        return self._session

    @property
    def last_error(self) -> Optional[str]:
        """Get the last error message for display to user."""
        return self._last_error

    def add_state_callback(self, callback: Callable[[RecordingState], None]):
        """Add a callback for state changes."""
        self._state_callbacks.append(callback)

    def _set_state(self, state: RecordingState):
        """Update state and notify callbacks."""
        self._state = state
        log_info(f"Recording state: {state.value}")
        for callback in self._state_callbacks:
            try:
                callback(state)
            except Exception as e:
                log_error(f"State callback error: {e}")

    def _set_error(self, message: str):
        """Set error message for display to user."""
        self._last_error = message
        log_error(message)

    def is_obs_running(self) -> bool:
        """Check if OBS is running."""
        for proc in psutil.process_iter(['name']):
            try:
                if proc.info['name'] and 'obs' in proc.info['name'].lower():
                    return True
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return False

    def launch_obs(self) -> bool:
        """Launch OBS Studio if not running."""
        if self.is_obs_running():
            log_info("[RecMgr] OBS is already running")
            return True

        obs_path = get_obs_path()
        if not obs_path.exists():
            self._set_error(f"OBS not found at: {obs_path}")
            return False

        try:
            log_info(f"[RecMgr] Launching OBS from: {obs_path}")
            # Launch OBS directly without shell=True for security
            subprocess.Popen(
                [str(obs_path)],
                cwd=str(obs_path.parent),
                creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
            )
            log_info("[RecMgr] OBS launch command sent")

            # Wait for OBS process to start (up to 20 seconds)
            log_debug("[RecMgr] Waiting for OBS process to start...")
            for i in range(20):
                time.sleep(1)
                if self.is_obs_running():
                    log_info(f"[RecMgr] OBS process detected after {i+1}s")
                    break
            else:
                self._set_error("OBS process did not start within 20 seconds")
                return False

            # Wait additional time for WebSocket server to initialize
            log_debug("[RecMgr] Waiting for OBS WebSocket to initialize...")
            time.sleep(5)

            # Check if WebSocket is listening
            if self._check_websocket_listening():
                log_info("[RecMgr] OBS WebSocket is ready")
                return True
            else:
                log_warning("[RecMgr] OBS started but WebSocket not detected on port 4455")
                log_warning("[RecMgr] Please ensure WebSocket Server is enabled in OBS:")
                log_warning("[RecMgr]   Tools -> WebSocket Server Settings -> Enable WebSocket Server")
                return True  # Still return True, connection will be retried

        except Exception as e:
            self._set_error(f"Failed to launch OBS: {e}")
            import traceback
            traceback.print_exc()
            return False

    def _check_websocket_listening(self) -> bool:
        """Check if something is listening on WebSocket port 4455."""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', 4455))
            sock.close()
            return result == 0
        except Exception:
            return False

    def connect_to_obs(self, max_retries: int = 30) -> bool:
        """Connect to OBS WebSocket."""
        log_debug("[RecMgr] connect_to_obs called")

        if self._ws is None:
            log_debug("[RecMgr] Creating new OBSWebSocketSync instance")
            self._ws = OBSWebSocketSync()

        if self._ws.connected:
            log_debug("[RecMgr] Already connected to OBS")
            return True

        log_info(f"[RecMgr] Connecting to OBS WebSocket (max {max_retries} retries)...")
        if self._ws.connect(max_retries=max_retries):
            log_info("[RecMgr] Connected! Creating OBSSourceManager")
            self._source_manager = OBSSourceManager(self._ws)

            # Test connection by getting version
            try:
                version_resp = self._ws.get_version()
                if version_resp.success:
                    obs_ver = version_resp.data.get("obsVersion", "unknown")
                    ws_ver = version_resp.data.get("obsWebSocketVersion", "unknown")
                    log_info(f"[RecMgr] OBS version: {obs_ver}, WebSocket: {ws_ver}")
            except Exception as e:
                log_warning(f"[RecMgr] Could not get OBS version: {e}")

            return True

        self._set_error("Failed to connect to OBS WebSocket. Make sure WebSocket is enabled in OBS (Tools > WebSocket Server Settings)")
        return False

    def disconnect_from_obs(self):
        """Disconnect from OBS WebSocket."""
        if self._ws:
            self._ws.disconnect()
            self._ws = None
            self._source_manager = None

    def create_project_folder(self, project_name: str) -> Optional[Path]:
        """Create the project folder structure."""
        project_path = get_project_path(project_name)

        try:
            ensure_dir(project_path)
            ensure_dir(project_path / "raw")
            ensure_dir(project_path / "exports")

            # Create metadata file
            metadata = {
                "projectName": project_name,
                "dateCreated": datetime.now().isoformat(),
                "recordings": []
            }

            with open(project_path / "metadata.json", 'w') as f:
                json.dump(metadata, f, indent=2)

            log_info(f"Created project folder: {project_path}")
            return project_path

        except Exception as e:
            self._set_error(f"Failed to create project folder: {e}")
            return None

    def _create_default_config(self, profile_name: str) -> ProfileConfiguration:
        """Create a default configuration for a profile."""
        log_info(f"[RecMgr] Creating default configuration for profile: {profile_name}")

        # Default configuration similar to Mac's createDefaultConfiguration()
        # Check for multi-camera profiles using explicit patterns
        profile_lower = profile_name.lower()
        is_multi_camera = (
            "7cammic" in profile_lower or
            "7cam" in profile_lower or
            "7-cam" in profile_lower or
            "multi" in profile_lower or
            profile_name.endswith("-7")
        )

        if is_multi_camera:
            # Multi-camera setup: 7 cameras, 7 mics (one per camera), 1 display
            # All sources export separately via ISO recording
            return ProfileConfiguration(
                profile_name=profile_name,
                displays=["Display 1"],
                cameras=[f"Camera {i}" for i in range(1, 8)],  # 7 cameras
                audio_inputs=[f"Mic {i}" for i in range(1, 8)],  # 7 mics
                is_configured=False
            )
        else:
            # Single camera setup
            return ProfileConfiguration(
                profile_name=profile_name,
                displays=["Display 1"],
                cameras=["Camera 1"],
                audio_inputs=["Microphone"],
                is_configured=False
            )

    def start_recording(
        self,
        project_name: str,
        profile_name: str,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> bool:
        """
        Start a recording session.
        Returns True if recording started successfully.
        """
        if self._state != RecordingState.IDLE:
            self._set_error("Cannot start recording: not in idle state")
            return False

        self._set_state(RecordingState.STARTING)
        self._last_error = None

        def progress(msg: str):
            log_info(msg)
            if on_progress:
                on_progress(msg)

        try:
            # Step 1: Create project folder
            log_debug("[RecMgr] Step 1: Creating project folder")
            progress("Creating project folder...")
            project_path = self.create_project_folder(project_name)
            if not project_path:
                raise Exception(f"Failed to create project folder: {self._last_error}")
            log_debug(f"[RecMgr] Project folder: {project_path}")

            # Set up session logging
            set_session_log(project_path)

            # Step 2: Launch OBS if needed
            log_debug("[RecMgr] Step 2: Checking OBS")
            progress("Checking OBS...")
            obs_running = self.is_obs_running()
            log_debug(f"[RecMgr] OBS running: {obs_running}")
            if not obs_running:
                progress("Launching OBS Studio...")
                if not self.launch_obs():
                    raise Exception(f"Failed to launch OBS: {self._last_error}")
                log_debug("[RecMgr] OBS launched successfully")

            # Step 3: Connect to OBS WebSocket
            log_debug("[RecMgr] Step 3: Connecting to OBS WebSocket")
            progress("Connecting to OBS...")
            if not self.connect_to_obs():
                raise Exception(f"Failed to connect to OBS WebSocket: {self._last_error}")
            log_debug("[RecMgr] WebSocket connected")

            # Step 4: Get profile configuration
            log_debug("[RecMgr] Step 4: Getting profile configuration")
            progress("Loading profile configuration...")
            profile_config = self._config_manager.get_profile(profile_name)
            if not profile_config:
                log_debug(f"[RecMgr] No saved config for {profile_name}, creating default")
                profile_config = self._create_default_config(profile_name)
            else:
                log_debug(f"[RecMgr] Loaded config: displays={profile_config.displays}, cameras={profile_config.cameras}")

            # Step 5: Ensure profile exists in OBS
            log_debug("[RecMgr] Step 5: Ensuring profile exists in OBS")
            progress("Checking OBS profile...")
            if not self._source_manager.ensure_profile_exists(profile_name):
                raise Exception(f"Failed to create/find profile '{profile_name}' in OBS")

            # Step 6: Configure profile (with verification)
            log_debug("[RecMgr] Step 6: Configuring OBS profile")
            progress(f"Configuring profile: {profile_name}...")
            if not self._source_manager.configure_profile(profile_config):
                raise Exception("Failed to configure profile - check OBS logs")
            log_debug("[RecMgr] Profile configured")

            # Step 7: Verify scene sources before recording
            log_debug("[RecMgr] Step 7: Verifying scene sources")
            progress("Verifying scene sources...")
            self._source_manager.verify_scene_sources(DEFAULT_SCENE_NAME, profile_config)

            # Step 8: Create session directory
            log_debug("[RecMgr] Step 8: Creating session directory")
            session_path = get_session_dir(project_path)
            ensure_dir(session_path)
            log_debug(f"[RecMgr] Session path: {session_path}")

            # Step 9: Set recording directory
            log_debug("[RecMgr] Step 9: Setting recording directory")
            progress("Setting recording directory...")
            raw_dir = str(project_path / "raw").replace("\\", "/")
            log_debug(f"[RecMgr] Raw dir: {raw_dir}")
            response = self._ws.set_record_directory(raw_dir)
            if not response.success:
                log_warning(f"[RecMgr] Failed to set record directory: {response.error_message}")
            else:
                log_debug("[RecMgr] Record directory set")

            # Step 10: Enable ISO recording (use scene name, not profile name!)
            log_debug("[RecMgr] Step 10: Enabling ISO recording")
            progress("Enabling ISO recording...")
            # FIX: Use DEFAULT_SCENE_NAME instead of profile_name
            self._source_manager.enable_iso_recording(DEFAULT_SCENE_NAME, raw_dir)
            log_debug("[RecMgr] ISO recording enabled")

            # Step 11: Start recording
            log_debug("[RecMgr] Step 11: Starting OBS recording")
            progress("Starting recording...")
            response = self._ws.start_record()
            if not response.success:
                raise Exception(f"Failed to start recording: {response.error_message}")
            log_debug("[RecMgr] Recording started successfully")

            # Create session info
            self._session = SessionInfo(
                project_name=project_name,
                project_path=project_path,
                session_path=session_path,
                profile_name=profile_name,
                scene_name=DEFAULT_SCENE_NAME
            )

            self._set_state(RecordingState.RECORDING)
            log_success(f"Recording started: {project_name}")
            return True

        except Exception as e:
            self._set_error(f"Start recording failed: {e}")
            self._set_state(RecordingState.IDLE)
            clear_session_log()
            return False

    def stop_recording(
        self,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> bool:
        """
        Stop the current recording session.
        Returns True if stopped successfully.
        """
        if self._state != RecordingState.RECORDING:
            self._set_error("Cannot stop recording: not recording")
            return False

        self._set_state(RecordingState.STOPPING)

        def progress(msg: str):
            log_info(msg)
            if on_progress:
                on_progress(msg)

        try:
            # Step 1: Stop OBS recording
            progress("Stopping OBS recording...")
            response = self._ws.stop_record()
            if not response.success:
                log_warning(f"Stop recording response: {response.error_message}")

            # Step 2: Wait for files to finish writing
            progress("Waiting for files to finalize...")
            time.sleep(3)

            # Step 3: Disable ISO recording
            if self._session:
                progress("Disabling ISO recording...")
                self._source_manager.disable_iso_recording(self._session.scene_name)

            # Step 4: Collect recordings
            progress("Collecting recordings...")
            self._collect_recordings()

            # Step 5: Transcribe the main recording
            progress("Starting transcription...")
            self._transcribe_recording()

            log_success("Recording stopped successfully")

            # Open project folder
            if self._session:
                try:
                    os.startfile(str(self._session.project_path))
                except Exception as e:
                    log_warning(f"Could not open project folder: {e}")

            return True

        except Exception as e:
            self._set_error(f"Stop recording failed: {e}")
            return False

        finally:
            self._session = None
            self._set_state(RecordingState.IDLE)
            clear_session_log()

    def _collect_recordings(self):
        """
        Collect ISO recordings from various locations.
        Moves files to the session folder.
        """
        if not self._session:
            return

        raw_dir = self._session.raw_dir
        videos_dir = get_videos_dir()
        start_time = self._session.start_time.timestamp()

        video_extensions = {'.mov', '.mkv', '.mp4', '.avi', '.flv'}
        collected_files = []

        # Search in both Videos folder (OBS default) and raw folder
        search_dirs = [videos_dir, raw_dir]

        for search_dir in search_dirs:
            if not search_dir.exists():
                continue

            for file_path in search_dir.iterdir():
                if not file_path.is_file():
                    continue
                if file_path.suffix.lower() not in video_extensions:
                    continue

                # Check if file was created during this session
                try:
                    mtime = file_path.stat().st_mtime
                    if mtime >= start_time:
                        collected_files.append(file_path)
                        log_debug(f"Found recording: {file_path.name}")
                except Exception:
                    pass

        if not collected_files:
            log_warning("No recordings found to collect")
            return

        # Create timestamped session folder
        timestamp = self._session.start_time.strftime("%Y-%m-%d %H-%M-%S")
        session_folder = raw_dir / timestamp
        ensure_dir(session_folder)

        # Move files to session folder
        for file_path in collected_files:
            # Clean up filename (remove OBS timestamp prefix if present)
            new_name = self._clean_filename(file_path.name, timestamp)
            dest_path = session_folder / new_name

            try:
                if file_path.parent != session_folder:
                    shutil.move(str(file_path), str(dest_path))
                    log_info(f"Collected: {file_path.name} -> {new_name}")
            except Exception as e:
                log_error(f"Failed to move {file_path.name}: {e}")

        log_success(f"Collected {len(collected_files)} recording(s)")

    def _clean_filename(self, filename: str, session_timestamp: str) -> str:
        """
        Clean up recording filename.
        Removes OBS timestamp prefixes, standardizes naming.
        """
        # Pattern: YYYY-MM-DD HH-MM-SS rest.ext
        pattern = r'^\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2} '
        cleaned = re.sub(pattern, '', filename)

        if cleaned == filename:
            # No timestamp removed, check for other patterns
            pattern2 = r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_'
            cleaned = re.sub(pattern2, '', filename)

        return cleaned if cleaned else filename

    def _transcribe_recording(self):
        """Transcribe the main recording audio."""
        if not self._session:
            return

        transcription_manager = get_transcription_manager()

        if not transcription_manager.is_available:
            log_warning("Transcription not available - faster-whisper not installed")
            log_warning("Install with: pip install faster-whisper")
            return

        # Find the session folder with recordings
        raw_dir = self._session.raw_dir
        if not raw_dir.exists():
            log_warning("No raw directory found for transcription")
            return

        # Find the most recent session folder
        session_folders = sorted([f for f in raw_dir.iterdir() if f.is_dir()], reverse=True)
        if not session_folders:
            log_warning("No session folders found for transcription")
            return

        session_folder = session_folders[0]

        # Find the main composite recording (usually the largest file or first video)
        video_files = list(session_folder.glob("*.mkv")) + list(session_folder.glob("*.mp4")) + list(session_folder.glob("*.mov"))

        if not video_files:
            log_warning("No video files found for transcription")
            return

        # Use the first (or largest) video file
        main_video = max(video_files, key=lambda f: f.stat().st_size)
        log_info(f"Transcribing: {main_video.name}")

        try:
            def on_progress(msg):
                log_info(f"[Transcription] {msg}")

            result = transcription_manager.transcribe_video(main_video, on_progress)

            if result.success:
                log_success(f"Transcription complete: {result.output_path}")
            else:
                log_warning(f"Transcription failed: {result.message}")

        except Exception as e:
            log_error(f"Transcription error: {e}")

    def _extract_audio(self):
        """Extract audio from composite recording using ffmpeg."""
        if not self._session:
            return

        session_folder = self._session.session_path
        if not session_folder.exists():
            # Find the actual session folder
            raw_dir = self._session.raw_dir
            folders = sorted(raw_dir.iterdir(), reverse=True)
            if folders:
                session_folder = folders[0]

        # Find composite recording
        composite = None
        for file_path in session_folder.iterdir():
            if 'composite' in file_path.name.lower() or file_path.stem == self._session.profile_name:
                composite = file_path
                break

        if not composite:
            # Use first video file
            for file_path in session_folder.iterdir():
                if file_path.suffix.lower() in {'.mov', '.mkv', '.mp4'}:
                    composite = file_path
                    break

        if not composite:
            log_warning("No composite recording found for audio extraction")
            return

        audio_path = session_folder / "audio.aac"

        try:
            subprocess.run([
                'ffmpeg', '-i', str(composite),
                '-vn', '-acodec', 'copy',
                str(audio_path)
            ], capture_output=True, timeout=120)

            if audio_path.exists():
                log_success(f"Extracted audio: {audio_path.name}")
            else:
                log_warning("Audio extraction produced no output")

        except FileNotFoundError:
            log_warning("ffmpeg not found, skipping audio extraction")
        except subprocess.TimeoutExpired:
            log_warning("Audio extraction timed out")
        except Exception as e:
            log_error(f"Audio extraction failed: {e}")

    def get_existing_projects(self) -> List[Dict]:
        """Get list of existing projects that can be continued."""
        projects = []
        base_dir = get_recordings_base()

        if not base_dir.exists():
            return projects

        for folder in sorted(base_dir.iterdir(), reverse=True):
            if not folder.is_dir():
                continue

            metadata_file = folder / "metadata.json"
            if metadata_file.exists():
                try:
                    with open(metadata_file, 'r') as f:
                        metadata = json.load(f)
                    projects.append({
                        'path': folder,
                        'name': metadata.get('projectName', folder.name),
                        'date': metadata.get('dateCreated', ''),
                    })
                except Exception:
                    projects.append({
                        'path': folder,
                        'name': folder.name,
                        'date': ''
                    })

        return projects[:10]  # Return last 10 projects
