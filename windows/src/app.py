"""
Main Application Controller for OBS Tutorial Recorder.
Coordinates all components and manages application state.
"""

import threading
from typing import Callable, List, Optional

from .core.recording_manager import RecordingManager, RecordingState
from .core.device_enumerator import get_device_enumerator, DeviceEnumerator
from .core.obs_websocket import OBSWebSocketSync
from .utils.config import get_config_manager, ConfigManager, ProfileConfiguration
from .utils.paths import init_directories, get_recordings_base
from .utils.logger import log_info, log_error, get_logger


class TutorialRecorderApp:
    """
    Main application controller.
    Manages recording, configuration, and UI coordination.
    """

    def __init__(self):
        # Initialize directories
        init_directories()

        # Core components
        self._recording_manager = RecordingManager()
        self._config_manager = get_config_manager()
        self._device_enum = get_device_enumerator()

        # State callbacks
        self._state_callbacks: List[Callable[[RecordingState], None]] = []
        self._recording_manager.add_state_callback(self._on_state_change)

        # UI reference (set by UI layer)
        self._ui = None

        log_info("Tutorial Recorder initialized")

    @property
    def recording_manager(self) -> RecordingManager:
        return self._recording_manager

    @property
    def config_manager(self) -> ConfigManager:
        return self._config_manager

    @property
    def device_enumerator(self) -> DeviceEnumerator:
        return self._device_enum

    @property
    def is_recording(self) -> bool:
        return self._recording_manager.is_recording

    @property
    def is_busy(self) -> bool:
        return self._recording_manager.is_busy

    @property
    def state(self) -> RecordingState:
        return self._recording_manager.state

    def get_last_error(self) -> Optional[str]:
        """Get the last error message from the recording manager."""
        return self._recording_manager.last_error

    def set_ui(self, ui):
        """Set UI reference for callbacks."""
        self._ui = ui

    def add_state_callback(self, callback: Callable[[RecordingState], None]):
        """Add callback for recording state changes."""
        self._state_callbacks.append(callback)

    def _on_state_change(self, state: RecordingState):
        """Handle recording state changes."""
        for callback in self._state_callbacks:
            try:
                callback(state)
            except Exception as e:
                log_error(f"State callback error: {e}")

    # Profile Management

    def get_profile_names(self) -> List[str]:
        """Get list of available profile names."""
        return self._config_manager.get_profile_names()

    def get_profile(self, name: str) -> Optional[ProfileConfiguration]:
        """Get a profile configuration by name."""
        return self._config_manager.get_profile(name)

    def save_profile(self, config: ProfileConfiguration):
        """Save a profile configuration."""
        self._config_manager.save_profile(config)

    # Device Enumeration

    def get_available_cameras(self) -> List[str]:
        """Get list of available camera names."""
        return self._device_enum.get_camera_names()

    def get_available_audio_inputs(self) -> List[str]:
        """Get list of available audio input names."""
        return self._device_enum.get_audio_input_names()

    def get_available_displays(self) -> List[str]:
        """Get list of available display names."""
        return self._device_enum.get_display_names()

    def refresh_devices(self):
        """Refresh device lists."""
        self._device_enum.refresh()

    # Recording Control

    def start_recording(
        self,
        project_name: str,
        profile_name: str,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> bool:
        """
        Start a recording session.
        Note: This is synchronous - caller should run in a thread if needed.
        """
        return self._recording_manager.start_recording(
            project_name, profile_name, on_progress
        )

    def stop_recording(
        self,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> bool:
        """
        Stop the current recording session.
        Note: This is synchronous - caller should run in a thread if needed.
        """
        return self._recording_manager.stop_recording(on_progress)

    def get_existing_projects(self) -> List[dict]:
        """Get list of existing projects that can be continued."""
        return self._recording_manager.get_existing_projects()

    # OBS Control

    def is_obs_running(self) -> bool:
        """Check if OBS is running."""
        return self._recording_manager.is_obs_running()

    def launch_obs(self) -> bool:
        """Launch OBS Studio."""
        return self._recording_manager.launch_obs()

    def open_obs(self):
        """Open OBS (launch if not running)."""
        if not self.is_obs_running():
            self.launch_obs()

    # Folder Operations

    def open_recordings_folder(self):
        """Open the recordings base folder."""
        import os
        folder = get_recordings_base()
        if folder.exists():
            os.startfile(str(folder))
        else:
            folder.mkdir(parents=True, exist_ok=True)
            os.startfile(str(folder))

    def open_project_folder(self):
        """Open the current project folder."""
        import os
        session = self._recording_manager.session
        if session and session.project_path.exists():
            os.startfile(str(session.project_path))

    # Cleanup

    def shutdown(self):
        """Clean shutdown of the application."""
        log_info("Shutting down Tutorial Recorder...")

        # Stop recording if active
        if self.is_recording:
            self._recording_manager.stop_recording()

        # Disconnect from OBS
        self._recording_manager.disconnect_from_obs()

        log_info("Shutdown complete")


# Global app instance
_app: Optional[TutorialRecorderApp] = None


def get_app() -> TutorialRecorderApp:
    """Get the global application instance."""
    global _app
    if _app is None:
        _app = TutorialRecorderApp()
    return _app


def shutdown_app():
    """Shutdown the global application instance."""
    global _app
    if _app:
        _app.shutdown()
        _app = None
