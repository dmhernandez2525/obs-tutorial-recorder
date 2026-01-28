"""
Windows path utilities for OBS Tutorial Recorder.
Handles all platform-specific path resolution.
"""

import os
from pathlib import Path


def get_home() -> Path:
    """Get user home directory."""
    return Path(os.path.expanduser("~"))


def get_desktop() -> Path:
    """Get user desktop directory."""
    return get_home() / "Desktop"


def get_recordings_base() -> Path:
    """
    Get base directory for tutorial recordings.
    Default: C:\\Users\\{user}\\Desktop\\Tutorial Recordings
    """
    return get_desktop() / "Tutorial Recordings"


def get_config_dir() -> Path:
    """
    Get configuration directory.
    Default: C:\\Users\\{user}\\AppData\\Roaming\\TutorialRecorder
    """
    appdata = os.environ.get("APPDATA", str(get_home() / "AppData" / "Roaming"))
    return Path(appdata) / "TutorialRecorder"


def get_cache_dir() -> Path:
    """
    Get cache directory (for whisper models, etc.).
    Default: C:\\Users\\{user}\\AppData\\Local\\TutorialRecorder
    """
    localappdata = os.environ.get("LOCALAPPDATA", str(get_home() / "AppData" / "Local"))
    return Path(localappdata) / "TutorialRecorder"


def get_videos_dir() -> Path:
    """
    Get user Videos directory (OBS default output).
    Default: C:\\Users\\{user}\\Videos
    """
    return get_home() / "Videos"


def get_obs_path() -> Path:
    """
    Get OBS Studio executable path.
    Checks common installation locations.
    """
    common_paths = [
        Path(r"C:\Program Files\obs-studio\bin\64bit\obs64.exe"),
        Path(r"C:\Program Files (x86)\obs-studio\bin\64bit\obs64.exe"),
        get_home() / "AppData" / "Local" / "Programs" / "obs-studio" / "bin" / "64bit" / "obs64.exe",
    ]

    for path in common_paths:
        if path.exists():
            return path

    # Return default path even if not found (let caller handle)
    return common_paths[0]


def get_obs_plugins_dir() -> Path:
    """Get OBS system plugins directory."""
    return Path(r"C:\Program Files\obs-studio\obs-plugins\64bit")


def get_obs_user_plugins_dir() -> Path:
    """Get OBS user plugins directory (AppData) - legacy location."""
    appdata = os.environ.get("APPDATA", str(get_home() / "AppData" / "Roaming"))
    return Path(appdata) / "obs-studio" / "obs-plugins" / "64bit"


def get_obs_user_plugin_path(plugin_name: str) -> Path:
    """Get OBS user plugin path for OBS 28+ format."""
    appdata = os.environ.get("APPDATA", str(get_home() / "AppData" / "Roaming"))
    return Path(appdata) / "obs-studio" / "plugins" / plugin_name / "bin" / "64bit" / f"{plugin_name}.dll"


def get_source_record_plugin_path() -> Path:
    """
    Get Source Record plugin path.
    Checks OBS 28+ user plugins, legacy user plugins, and system locations.
    """
    # Check OBS 28+ user plugins format first (correct location)
    user_path_new = get_obs_user_plugin_path("source-record")
    if user_path_new.exists():
        return user_path_new

    # Check legacy user plugins location
    user_path_legacy = get_obs_user_plugins_dir() / "source-record.dll"
    if user_path_legacy.exists():
        return user_path_legacy

    # Then check system plugins
    system_path = get_obs_plugins_dir() / "source-record.dll"
    if system_path.exists():
        return system_path

    # Return new format path as default (that's where we install)
    return user_path_new


def get_profile_configs_path() -> Path:
    """Get path to profile configurations JSON."""
    return get_config_dir() / "profile-configs.json"


def get_sync_config_path() -> Path:
    """Get path to sync configuration JSON."""
    return get_config_dir() / "sync-config.json"


def get_transcription_config_path() -> Path:
    """Get path to transcription configuration JSON."""
    return get_config_dir() / "transcription-config.json"


def get_app_log_path() -> Path:
    """Get path to application log file."""
    return get_config_dir() / "app.log"


def get_whisper_models_dir() -> Path:
    """Get directory for Whisper model files."""
    return get_cache_dir() / "whisper"


def get_rclone_config_path() -> Path:
    """Get rclone configuration file path."""
    appdata = os.environ.get("APPDATA", str(get_home() / "AppData" / "Roaming"))
    return Path(appdata) / "rclone" / "rclone.conf"


def ensure_dir(path: Path) -> Path:
    """Ensure directory exists, create if needed."""
    path.mkdir(parents=True, exist_ok=True)
    return path


def get_project_path(project_name: str) -> Path:
    """
    Get path for a specific project.
    Format: Tutorial Recordings/YYYY-MM-DD_project-name/
    """
    from datetime import datetime
    date_str = datetime.now().strftime("%Y-%m-%d")
    safe_name = project_name.replace(" ", "-").replace("/", "-").replace("\\", "-")
    return get_recordings_base() / f"{date_str}_{safe_name}"


def get_session_dir(project_path: Path) -> Path:
    """
    Get session directory within a project.
    Format: raw/YYYY-MM-DD HH-MM-SS/
    """
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H-%M-%S")
    return project_path / "raw" / timestamp


def init_directories():
    """Initialize all required directories."""
    ensure_dir(get_recordings_base())
    ensure_dir(get_config_dir())
    ensure_dir(get_cache_dir())
    ensure_dir(get_whisper_models_dir())
