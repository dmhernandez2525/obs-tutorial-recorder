"""
Configuration management for OBS Tutorial Recorder.
Handles profile configs, sync settings, and transcription settings.
"""

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional

from .paths import (
    get_profile_configs_path,
    get_sync_config_path,
    get_transcription_config_path,
    get_recordings_base,
    ensure_dir,
)
from .logger import log_info, log_error, log_warning


@dataclass
class ProfileConfiguration:
    """Configuration for an OBS recording profile."""
    profile_name: str
    displays: List[str] = field(default_factory=list)
    cameras: List[str] = field(default_factory=list)
    audio_inputs: List[str] = field(default_factory=list)
    is_configured: bool = False

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "ProfileConfiguration":
        return cls(
            profile_name=data.get("profile_name", data.get("profileName", "")),
            displays=data.get("displays", []),
            cameras=data.get("cameras", []),
            audio_inputs=data.get("audio_inputs", data.get("audioInputs", [])),
            is_configured=data.get("is_configured", data.get("isConfigured", False)),
        )


@dataclass
class SyncConfig:
    """Configuration for cloud sync (rclone)."""
    rclone_remote: str = "tutorial-recordings"
    local_path: str = ""
    remote_path: str = "Tutorial Recordings"
    auto_sync: bool = False
    sync_exports_only: bool = False
    exclude_patterns: List[str] = field(default_factory=lambda: ["*.tmp", "*.part"])

    def __post_init__(self):
        if not self.local_path:
            self.local_path = str(get_recordings_base())

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "SyncConfig":
        return cls(
            rclone_remote=data.get("rclone_remote", "tutorial-recordings"),
            local_path=data.get("local_path", str(get_recordings_base())),
            remote_path=data.get("remote_path", "Tutorial Recordings"),
            auto_sync=data.get("auto_sync", False),
            sync_exports_only=data.get("sync_exports_only", False),
            exclude_patterns=data.get("exclude_patterns", ["*.tmp", "*.part"]),
        )


@dataclass
class TranscriptionConfig:
    """Configuration for Whisper transcription."""
    enabled: bool = False
    auto_transcribe: bool = False
    model: str = "small"  # tiny, base, small, medium
    language: str = "en"

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "TranscriptionConfig":
        return cls(
            enabled=data.get("enabled", False),
            auto_transcribe=data.get("auto_transcribe", False),
            model=data.get("model", "small"),
            language=data.get("language", "en"),
        )


class ConfigManager:
    """Manages all configuration files."""

    def __init__(self):
        self._profiles: Dict[str, ProfileConfiguration] = {}
        self._sync_config: Optional[SyncConfig] = None
        self._transcription_config: Optional[TranscriptionConfig] = None
        self._load_all()

    def _load_all(self):
        """Load all configuration files."""
        self._load_profiles()
        self._load_sync_config()
        self._load_transcription_config()

    # Profile Configuration

    def _load_profiles(self):
        """Load profile configurations from JSON."""
        path = get_profile_configs_path()
        if path.exists():
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                self._profiles = {
                    name: ProfileConfiguration.from_dict(config)
                    for name, config in data.items()
                }
                log_info(f"Loaded {len(self._profiles)} profile configurations")
            except Exception as e:
                log_error(f"Failed to load profile configs: {e}")
                self._profiles = {}
        else:
            self._profiles = {}
            self._create_default_profiles()

    def _create_default_profiles(self):
        """Create default profile configurations."""
        defaults = {
            "PC-Single": ProfileConfiguration(
                profile_name="PC-Single",
                displays=["Display 1"],
                cameras=["Camera 1"],
                audio_inputs=["Microphone"],
                is_configured=False,
            ),
            "PC-7CamMic": ProfileConfiguration(
                profile_name="PC-7CamMic",
                displays=["Display 1"],
                cameras=[f"Camera {i}" for i in range(1, 8)],  # 7 cameras
                audio_inputs=[f"Mic {i}" for i in range(1, 8)],  # 7 mics
                is_configured=False,
            ),
        }
        self._profiles = defaults
        self._save_profiles()
        log_info("Created default profile configurations")

    def _save_profiles(self):
        """Save profile configurations to JSON."""
        path = get_profile_configs_path()
        ensure_dir(path.parent)
        try:
            data = {name: config.to_dict() for name, config in self._profiles.items()}
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            log_info("Saved profile configurations")
        except Exception as e:
            log_error(f"Failed to save profile configs: {e}")

    def get_profile(self, name: str) -> Optional[ProfileConfiguration]:
        """Get a profile configuration by name."""
        return self._profiles.get(name)

    def get_all_profiles(self) -> Dict[str, ProfileConfiguration]:
        """Get all profile configurations."""
        return self._profiles.copy()

    def get_profile_names(self) -> List[str]:
        """Get list of profile names."""
        return list(self._profiles.keys())

    def save_profile(self, config: ProfileConfiguration):
        """Save a profile configuration."""
        self._profiles[config.profile_name] = config
        self._save_profiles()

    def delete_profile(self, name: str):
        """Delete a profile configuration."""
        if name in self._profiles:
            del self._profiles[name]
            self._save_profiles()

    # Sync Configuration

    def _load_sync_config(self):
        """Load sync configuration from JSON."""
        path = get_sync_config_path()
        if path.exists():
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                self._sync_config = SyncConfig.from_dict(data)
                log_info("Loaded sync configuration")
            except Exception as e:
                log_error(f"Failed to load sync config: {e}")
                self._sync_config = SyncConfig()
        else:
            self._sync_config = SyncConfig()

    def get_sync_config(self) -> SyncConfig:
        """Get sync configuration."""
        if self._sync_config is None:
            self._sync_config = SyncConfig()
        return self._sync_config

    def save_sync_config(self, config: SyncConfig):
        """Save sync configuration."""
        self._sync_config = config
        path = get_sync_config_path()
        ensure_dir(path.parent)
        try:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(config.to_dict(), f, indent=2)
            log_info("Saved sync configuration")
        except Exception as e:
            log_error(f"Failed to save sync config: {e}")

    # Transcription Configuration

    def _load_transcription_config(self):
        """Load transcription configuration from JSON."""
        path = get_transcription_config_path()
        if path.exists():
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                self._transcription_config = TranscriptionConfig.from_dict(data)
                log_info("Loaded transcription configuration")
            except Exception as e:
                log_error(f"Failed to load transcription config: {e}")
                self._transcription_config = TranscriptionConfig()
        else:
            self._transcription_config = TranscriptionConfig()

    def get_transcription_config(self) -> TranscriptionConfig:
        """Get transcription configuration."""
        if self._transcription_config is None:
            self._transcription_config = TranscriptionConfig()
        return self._transcription_config

    def save_transcription_config(self, config: TranscriptionConfig):
        """Save transcription configuration."""
        self._transcription_config = config
        path = get_transcription_config_path()
        ensure_dir(path.parent)
        try:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(config.to_dict(), f, indent=2)
            log_info("Saved transcription configuration")
        except Exception as e:
            log_error(f"Failed to save transcription config: {e}")


# Global config manager instance
_config_manager: Optional[ConfigManager] = None


def get_config_manager() -> ConfigManager:
    """Get the global config manager instance."""
    global _config_manager
    if _config_manager is None:
        _config_manager = ConfigManager()
    return _config_manager
