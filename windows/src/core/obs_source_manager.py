"""
OBS Source Manager for Windows.
Handles profile, scene, and source configuration via WebSocket.
"""

import time
from pathlib import Path
from typing import List, Optional, Tuple

from .obs_websocket import OBSWebSocketSync, OBSResponse
from .device_enumerator import get_device_enumerator, VideoDevice, AudioDevice
from ..utils.config import ProfileConfiguration
from ..utils.paths import get_source_record_plugin_path, get_obs_plugins_dir
from ..utils.logger import log_info, log_error, log_warning, log_debug, log_success


# Windows OBS input kinds
INPUT_KIND_MONITOR = "monitor_capture"
INPUT_KIND_WINDOW = "window_capture"
INPUT_KIND_GAME = "game_capture"
INPUT_KIND_CAMERA = "dshow_input"
INPUT_KIND_AUDIO = "wasapi_input_capture"

# Source Record plugin
SOURCE_RECORD_FILTER_KIND = "source_record_filter"
ISO_FILTER_NAME = "ISO_Record"

# Default scene name - consistent across all profiles (like Mac version)
DEFAULT_SCENE_NAME = "Tutorial Recording"

# Default camera resolution
DEFAULT_CAMERA_RESOLUTION = "1920x1080"


class OBSSourceManager:
    """
    Manages OBS profiles, scenes, and sources.
    Configures recording setup via WebSocket.
    """

    def __init__(self, websocket: OBSWebSocketSync):
        self.ws = websocket
        self._device_enum = get_device_enumerator()
        self._source_record_plugin_installed: Optional[bool] = None

    def is_source_record_plugin_installed(self) -> bool:
        """Check if Source Record plugin is installed."""
        if self._source_record_plugin_installed is not None:
            return self._source_record_plugin_installed

        plugin_path = get_source_record_plugin_path()
        if plugin_path.exists():
            log_info("Source Record plugin found")
            self._source_record_plugin_installed = True
            return True

        # Also check in 32-bit plugins folder
        alt_path = get_obs_plugins_dir().parent / "32bit" / "source-record.dll"
        if alt_path.exists():
            log_info("Source Record plugin found (32-bit)")
            self._source_record_plugin_installed = True
            return True

        log_warning("Source Record plugin not found")
        log_warning("Install from: https://obsproject.com/forum/resources/source-record.1285/")
        self._source_record_plugin_installed = False
        return False

    def clear_plugin_cache(self):
        """Clear cached plugin check result."""
        self._source_record_plugin_installed = None

    # =========================================================================
    # PROFILE MANAGEMENT
    # =========================================================================

    def get_profile_list(self) -> Tuple[List[str], Optional[str]]:
        """Get list of all profiles and current profile name."""
        response = self.ws.get_profile_list()
        if not response.success:
            log_error(f"Failed to get profile list: {response.error_message}")
            return [], None

        profiles = response.data.get("profiles", [])
        profile_names = [p.get("profileName", p) if isinstance(p, dict) else p for p in profiles]
        current_profile = response.data.get("currentProfileName")

        log_debug(f"[SrcMgr] Found {len(profile_names)} profiles, current: {current_profile}")
        return profile_names, current_profile

    def ensure_profile_exists(self, profile_name: str) -> bool:
        """
        Ensure a profile exists in OBS, create if needed.
        Returns True if profile exists or was created.
        """
        profile_names, _ = self.get_profile_list()

        if profile_name in profile_names:
            log_debug(f"Profile '{profile_name}' already exists in OBS")
            return True

        # Create the profile
        log_info(f"Creating profile '{profile_name}' in OBS...")
        response = self.ws.create_profile(profile_name)
        if response.success:
            log_success(f"Created profile: {profile_name}")
            time.sleep(1.0)  # Wait for profile to be created
            return True
        else:
            # Error code 601 means it already exists
            if response.error_code == 601:
                return True
            log_error(f"Failed to create profile: {response.error_message}")
            return False

    def ensure_all_profiles_exist(self, profile_names: List[str]) -> bool:
        """Ensure all required profiles exist in OBS."""
        log_info("Ensuring all required OBS profiles exist...")
        all_success = True
        for name in profile_names:
            if not self.ensure_profile_exists(name):
                all_success = False
        return all_success

    def switch_to_profile(self, profile_name: str) -> bool:
        """
        Switch OBS to the specified profile.
        ALWAYS waits for profile to stabilize (matching Mac behavior).
        Returns True if successful.
        """
        current = self.ws.get_current_profile()

        if current == profile_name:
            log_debug(f"Already on profile: {profile_name}")
            # IMPORTANT: Still wait for profile to be fully loaded
            # This fixes the race condition where profile sources aren't ready
            log_debug("[SrcMgr] Waiting for profile to stabilize...")
            time.sleep(2.0)
            return True

        log_info(f"Switching from '{current}' to '{profile_name}'...")
        response = self.ws.set_current_profile(profile_name)
        if response.success:
            log_info(f"Switched to profile: {profile_name}")
            # Wait for profile to fully load (matching Mac's 3 second wait)
            log_debug("[SrcMgr] Waiting for profile to stabilize...")
            time.sleep(3.0)
            return True
        else:
            log_error(f"Failed to switch profile: {response.error_message}")
            return False

    # =========================================================================
    # SCENE MANAGEMENT
    # =========================================================================

    def get_scene_list(self) -> List[str]:
        """Get list of all scene names."""
        response = self.ws.get_scene_list()
        if not response.success:
            log_error(f"Failed to get scene list: {response.error_message}")
            return []

        scenes = response.data.get("scenes", [])
        return [s.get("sceneName", s) if isinstance(s, dict) else s for s in scenes]

    def ensure_scene_exists(self, scene_name: str) -> bool:
        """
        Ensure a scene exists in OBS, create if needed.
        """
        scenes = self.get_scene_list()

        if scene_name in scenes:
            log_debug(f"Scene '{scene_name}' already exists")
            return True

        log_info(f"Creating scene: {scene_name}")
        response = self.ws.create_scene(scene_name)
        if response.success:
            log_success(f"Created scene: {scene_name}")
            time.sleep(0.5)
            return True
        else:
            if response.error_code == 601:
                return True
            log_error(f"Failed to create scene: {response.error_message}")
            return False

    def set_current_scene(self, scene_name: str) -> bool:
        """Set the current program scene."""
        response = self.ws.set_current_program_scene(scene_name)
        if response.success:
            log_debug(f"Set current scene: {scene_name}")
            return True
        else:
            log_warning(f"Failed to set current scene: {response.error_message}")
            return False

    def clear_scene(self, scene_name: str) -> bool:
        """
        Remove all items from a scene with proper timing.
        """
        log_info(f"Clearing scene: {scene_name}")

        response = self.ws.get_scene_item_list(scene_name)
        if not response.success:
            log_error(f"Failed to get scene items: {response.error_message}")
            return False

        items = response.data.get("sceneItems", [])
        if not items:
            log_debug("Scene is already empty")
            return True

        log_debug(f"Removing {len(items)} items from scene...")
        removed_count = 0

        for item in items:
            item_id = item.get("sceneItemId")
            source_name = item.get("sourceName", "unknown")
            if item_id is not None:
                remove_response = self.ws.remove_scene_item(scene_name, item_id)
                if remove_response.success:
                    log_debug(f"Removed: {source_name} (id={item_id})")
                    removed_count += 1
                else:
                    log_warning(f"Failed to remove {source_name}: {remove_response.error_message}")
                # Wait between removals to avoid race conditions
                time.sleep(0.2)

        log_info(f"Cleared scene: {removed_count}/{len(items)} items removed")
        # Wait for scene to stabilize after clearing
        time.sleep(1.0)
        return True

    def get_scene_sources(self, scene_name: str) -> List[str]:
        """Get list of source names in a scene."""
        response = self.ws.get_scene_item_list(scene_name)
        if response.success:
            items = response.data.get("sceneItems", [])
            return [item.get("sourceName") for item in items if item.get("sourceName")]
        return []

    # =========================================================================
    # SOURCE CREATION
    # =========================================================================

    def create_display_capture(
        self,
        scene_name: str,
        source_name: str,
        display_index: int = 0
    ) -> bool:
        """
        Create a display capture source.
        Handles existing sources by adding them to the scene.
        """
        settings = {
            "monitor": display_index,
            "capture_cursor": True
        }

        response = self.ws.create_input(
            scene_name=scene_name,
            input_name=source_name,
            input_kind=INPUT_KIND_MONITOR,
            input_settings=settings
        )

        if response.success:
            log_info(f"Created display capture: {source_name} (Display {display_index + 1})")
            return True
        elif response.error_code == 601:
            # Source already exists globally - add it to the scene
            log_debug(f"Display capture '{source_name}' exists, adding to scene...")
            return self._add_existing_source_to_scene(scene_name, source_name)
        else:
            log_error(f"Failed to create display capture: {response.error_message}")
            return False

    def create_camera_capture(
        self,
        scene_name: str,
        source_name: str,
        device_name: str
    ) -> bool:
        """
        Create a camera (DirectShow video) capture source.
        If device_name is generic (like "Camera 1"), tries to find actual device.
        """
        # Try to get the actual device ID
        device = self._device_enum.find_camera_by_name(device_name)

        if device:
            device_id = device.device_id
            log_debug(f"Found device '{device_name}' -> '{device_id}'")
        else:
            # If device_name is a generic name like "Camera 1", try to use index
            if device_name.lower().startswith("camera "):
                try:
                    # Extract index from "Camera N" and get device by index
                    index = int(device_name.split()[-1]) - 1
                    cameras = self._device_enum.get_cameras()
                    if 0 <= index < len(cameras):
                        device_id = cameras[index].device_id
                        log_info(f"Mapped '{device_name}' to device: {cameras[index].name} ({device_id})")
                    else:
                        device_id = device_name
                        log_warning(f"No camera at index {index}, using name as-is")
                except (ValueError, IndexError):
                    device_id = device_name
                    log_warning(f"Could not parse camera index from '{device_name}'")
            else:
                device_id = device_name
                log_warning(f"Device '{device_name}' not found, using name as ID")

        settings = {
            "video_device_id": device_id,
            "res_type": 1,  # Custom resolution
            "resolution": DEFAULT_CAMERA_RESOLUTION,
        }

        response = self.ws.create_input(
            scene_name=scene_name,
            input_name=source_name,
            input_kind=INPUT_KIND_CAMERA,
            input_settings=settings
        )

        if response.success:
            log_info(f"Created camera capture: {source_name} ({device_id})")
            return True
        elif response.error_code == 601:
            # Source already exists globally - add it to the scene
            log_debug(f"Camera capture '{source_name}' exists, adding to scene...")
            added = self._add_existing_source_to_scene(scene_name, source_name)
            if added:
                # Update the device settings to ensure correct device
                self.ws.set_input_settings(source_name, {"video_device_id": device_id})
            return added
        else:
            log_error(f"Failed to create camera capture: {response.error_message}")
            return False

    def create_audio_capture(
        self,
        scene_name: str,
        source_name: str,
        device_name: str
    ) -> bool:
        """
        Create an audio input capture source.
        If device_name is generic (like "Mic 1"), tries to find actual device by index.
        """
        device = self._device_enum.find_audio_by_name(device_name)

        if device:
            device_id = device.device_id
            log_debug(f"Found audio device '{device_name}' -> '{device_id}'")
        else:
            # Check for generic names like "Mic 1", "Mic 2", etc.
            if device_name.lower().startswith("mic "):
                try:
                    # Extract index from "Mic N" and get device by index
                    index = int(device_name.split()[-1]) - 1
                    audio_devices = self._device_enum.get_audio_inputs()
                    if 0 <= index < len(audio_devices):
                        device_id = audio_devices[index].device_id
                        log_info(f"Mapped '{device_name}' to audio device: {audio_devices[index].name} ({device_id})")
                    else:
                        device_id = "default"
                        log_warning(f"No audio device at index {index}, using default")
                except (ValueError, IndexError):
                    device_id = "default"
                    log_warning(f"Could not parse mic index from '{device_name}', using default")
            elif device_name.lower() in ["microphone", "mic", "audio", "default"]:
                # Use default device for generic single-mic names
                device_id = "default"
                log_info(f"Using default audio device for '{device_name}'")
            else:
                # Try to use the first available audio device
                audio_devices = self._device_enum.get_audio_inputs()
                if audio_devices:
                    device_id = audio_devices[0].device_id
                    log_info(f"Mapped '{device_name}' to first audio device: {audio_devices[0].name}")
                else:
                    device_id = "default"
                    log_warning(f"No audio devices found, using default")

        settings = {
            "device_id": device_id
        }

        response = self.ws.create_input(
            scene_name=scene_name,
            input_name=source_name,
            input_kind=INPUT_KIND_AUDIO,
            input_settings=settings
        )

        if response.success:
            log_info(f"Created audio capture: {source_name} ({device_id})")
            return True
        elif response.error_code == 601:
            # Source already exists globally - add it to the scene
            log_debug(f"Audio capture '{source_name}' exists, adding to scene...")
            added = self._add_existing_source_to_scene(scene_name, source_name)
            if added:
                # Update the device settings
                self.ws.set_input_settings(source_name, {"device_id": device_id})
            return added
        else:
            log_error(f"Failed to create audio capture: {response.error_message}")
            return False

    def _add_existing_source_to_scene(self, scene_name: str, source_name: str) -> bool:
        """Add an existing global source to a scene."""
        response = self.ws.send_request("CreateSceneItem", {
            "sceneName": scene_name,
            "sourceName": source_name
        })

        if response.success:
            log_info(f"Added existing source '{source_name}' to scene '{scene_name}'")
            return True
        elif response.error_code == 601:
            # Already in scene
            log_debug(f"Source '{source_name}' already in scene")
            return True
        else:
            log_error(f"Failed to add source to scene: {response.error_message}")
            return False

    # =========================================================================
    # VERIFICATION AND AUTO-FIX (Like Mac version)
    # =========================================================================

    def verify_profile_configuration(
        self,
        profile_config: ProfileConfiguration,
        scene_name: Optional[str] = None
    ) -> Tuple[bool, str]:
        """
        Verify that the current OBS configuration matches the profile.
        Returns (matches, description).
        """
        if scene_name is None:
            scene_name = DEFAULT_SCENE_NAME

        current_sources = self.get_scene_sources(scene_name)

        # Build expected source names
        expected = set()
        for idx, _ in enumerate(profile_config.displays):
            expected.add(f"Display {idx + 1}")
        expected.update(profile_config.cameras)
        expected.update(profile_config.audio_inputs)

        current = set(current_sources)

        if expected == current:
            return True, "Configuration matches"

        missing = expected - current
        extra = current - expected

        msg_parts = []
        if missing:
            msg_parts.append(f"Missing: {', '.join(missing)}")
        if extra:
            msg_parts.append(f"Extra: {', '.join(extra)}")

        return False, "; ".join(msg_parts)

    def check_if_profile_configured(
        self,
        scene_name: str,
        expected_config: ProfileConfiguration
    ) -> bool:
        """
        Check if a scene exists with the correct sources.
        Like Mac's checkIfProfileConfigured().
        """
        log_info(f"Checking if scene '{scene_name}' is correctly configured...")

        # Check if scene exists
        scenes = self.get_scene_list()
        if scene_name not in scenes:
            log_info(f"Scene '{scene_name}' does not exist - needs configuration")
            return False

        log_debug(f"Scene '{scene_name}' exists - checking sources...")

        # Get actual sources
        actual_sources = set(self.get_scene_sources(scene_name))

        # Build expected sources
        expected_sources = set()
        for idx, _ in enumerate(expected_config.displays):
            expected_sources.add(f"Display {idx + 1}")
        expected_sources.update(expected_config.cameras)
        expected_sources.update(expected_config.audio_inputs)

        log_debug(f"Actual sources: {actual_sources}")
        log_debug(f"Expected sources: {expected_sources}")

        missing = expected_sources - actual_sources
        extra = actual_sources - expected_sources

        if missing:
            log_warning(f"Missing sources: {missing}")
            return False

        if extra:
            # Extra sources are okay - just log a warning, don't fail
            log_warning(f"Extra sources in scene (not in config): {extra}")
            log_info("Extra sources are allowed - scene has all required sources")

        log_success(f"Scene '{scene_name}' has all expected sources")
        return True

    def verify_and_fix_input_settings(
        self,
        scene_name: str,
        config: ProfileConfiguration
    ) -> bool:
        """
        Verify that all inputs have their devices properly configured.
        Auto-fixes broken device assignments.
        Like Mac's verifyAndFixInputSettings().
        """
        log_info(f"Verifying input settings for scene '{scene_name}'...")
        all_ok = True

        # Check cameras
        for camera_name in config.cameras:
            if not self._verify_and_fix_camera(camera_name):
                all_ok = False

        # Check audio inputs
        for audio_name in config.audio_inputs:
            if not self._verify_and_fix_audio(audio_name):
                all_ok = False

        return all_ok

    def _verify_and_fix_camera(self, input_name: str) -> bool:
        """Verify a camera input has correct device, fix if needed."""
        log_debug(f"Checking camera: {input_name}")

        # Get current settings
        response = self.ws.get_input_settings(input_name)
        if not response.success:
            log_warning(f"Could not get settings for {input_name}")
            return False

        current_settings = response.data.get("inputSettings", {})
        current_device = current_settings.get("video_device_id", "")

        # Find expected device
        device = self._device_enum.find_camera_by_name(input_name)
        expected_device = device.device_id if device else None

        if not expected_device:
            log_warning(f"Could not find device for camera '{input_name}'")
            return False

        if current_device == expected_device:
            log_debug(f"Camera '{input_name}' has correct device")
            return True

        # Fix the device setting
        log_warning(f"Camera '{input_name}' has wrong device, fixing...")
        fix_response = self.ws.set_input_settings(
            input_name,
            {"video_device_id": expected_device}
        )

        if fix_response.success:
            log_success(f"Fixed camera '{input_name}' -> {expected_device}")
            return True
        else:
            log_error(f"Failed to fix camera '{input_name}'")
            return False

    def _verify_and_fix_audio(self, input_name: str) -> bool:
        """Verify an audio input has correct device, fix if needed."""
        log_debug(f"Checking audio: {input_name}")

        # Get current settings
        response = self.ws.get_input_settings(input_name)
        if not response.success:
            log_warning(f"Could not get settings for {input_name}")
            return False

        current_settings = response.data.get("inputSettings", {})
        current_device = current_settings.get("device_id", "")

        # Empty device_id means no device selected
        if not current_device:
            log_warning(f"Audio '{input_name}' has no device selected, fixing...")

            # Find a device
            device = self._device_enum.find_audio_by_name(input_name)
            device_id = device.device_id if device else "default"

            fix_response = self.ws.set_input_settings(
                input_name,
                {"device_id": device_id}
            )

            if fix_response.success:
                log_success(f"Fixed audio '{input_name}' -> {device_id}")
                return True
            else:
                log_error(f"Failed to fix audio '{input_name}'")
                return False

        log_debug(f"Audio '{input_name}' has device configured")
        return True

    def verify_scene_sources(self, scene_name: str, config: ProfileConfiguration):
        """
        Log detailed verification of scene sources.
        Like Mac's verifySceneSources().
        """
        log_info("=" * 50)
        log_info("VERIFYING SCENE SOURCES BEFORE RECORDING")
        log_info("=" * 50)
        log_info(f"Scene: {scene_name}")

        sources = self.get_scene_sources(scene_name)

        if not sources:
            log_warning(f"NO SOURCES FOUND IN SCENE '{scene_name}'!")
            log_warning("This profile may not be configured correctly.")
        else:
            log_info(f"Found {len(sources)} source(s):")
            for idx, source in enumerate(sources):
                log_info(f"  [{idx + 1}] {source}")

        # Expected sources
        expected = []
        for idx, _ in enumerate(config.displays):
            expected.append(f"Display {idx + 1}")
        expected.extend(config.cameras)
        expected.extend(config.audio_inputs)

        log_info(f"Expected {len(expected)} source(s):")
        for source in expected:
            log_info(f"  - {source}")

        # Check for mismatches
        actual_set = set(sources)
        expected_set = set(expected)
        missing = expected_set - actual_set
        extra = actual_set - expected_set

        if missing:
            log_error("MISSING SOURCES:")
            for s in missing:
                log_error(f"  - {s}")

        if extra:
            log_warning("Extra sources (not in config):")
            for s in extra:
                log_warning(f"  - {s}")

        if not missing and not extra:
            log_success("All sources match expected configuration!")

        log_info("=" * 50)

    # =========================================================================
    # PROFILE CONFIGURATION
    # =========================================================================

    def configure_profile(
        self,
        profile_config: ProfileConfiguration,
        scene_name: Optional[str] = None
    ) -> bool:
        """
        Configure a complete OBS profile with scenes and sources.
        Uses DEFAULT_SCENE_NAME for consistency (like Mac version).
        """
        profile_name = profile_config.profile_name
        if scene_name is None:
            scene_name = DEFAULT_SCENE_NAME

        log_info(f"[SrcMgr] Configuring profile: {profile_name}")
        log_info(f"[SrcMgr] Scene name: {scene_name}")
        log_debug(f"[SrcMgr] Config: displays={profile_config.displays}, cameras={profile_config.cameras}, audio={profile_config.audio_inputs}")

        # Step 1: Ensure profile exists and switch to it
        log_debug(f"[SrcMgr] Ensuring profile exists: {profile_name}")
        if not self.ensure_profile_exists(profile_name):
            log_error(f"[SrcMgr] Failed to ensure profile exists")
            return False

        log_debug(f"[SrcMgr] Switching to profile: {profile_name}")
        if not self.switch_to_profile(profile_name):
            log_error(f"[SrcMgr] Failed to switch to profile")
            return False

        # Step 2: Check if already correctly configured
        if self.check_if_profile_configured(scene_name, profile_config):
            log_success(f"[SrcMgr] Profile '{profile_name}' is already configured correctly!")

            # Verify and fix input settings
            log_debug("[SrcMgr] Verifying input device settings...")
            self.verify_and_fix_input_settings(scene_name, profile_config)

            # Set scene as current
            self.set_current_scene(scene_name)
            return True

        # Step 3: Need to configure - ensure scene exists
        log_info(f"[SrcMgr] Profile needs configuration...")
        log_debug(f"[SrcMgr] Ensuring scene exists: {scene_name}")
        if not self.ensure_scene_exists(scene_name):
            log_error(f"[SrcMgr] Failed to ensure scene exists")
            return False

        # Step 4: Set as current scene
        log_debug(f"[SrcMgr] Setting program scene: {scene_name}")
        self.set_current_scene(scene_name)
        time.sleep(0.5)

        # Step 5: Clear existing sources
        log_debug(f"[SrcMgr] Clearing scene: {scene_name}")
        self.clear_scene(scene_name)

        # Step 6: Add display captures
        log_debug(f"[SrcMgr] Adding {len(profile_config.displays)} display(s)")
        for idx, display_name in enumerate(profile_config.displays):
            source_name = f"Display {idx + 1}"
            log_debug(f"[SrcMgr] Creating display capture: {source_name} (index {idx})")
            self.create_display_capture(scene_name, source_name, idx)
            time.sleep(0.3)

        # Step 7: Add camera captures
        log_debug(f"[SrcMgr] Adding {len(profile_config.cameras)} camera(s)")
        for camera_name in profile_config.cameras:
            source_name = camera_name
            log_debug(f"[SrcMgr] Creating camera capture: {source_name}")
            self.create_camera_capture(scene_name, source_name, camera_name)
            time.sleep(0.3)

        # Step 8: Add audio captures
        log_debug(f"[SrcMgr] Adding {len(profile_config.audio_inputs)} audio input(s)")
        for audio_name in profile_config.audio_inputs:
            source_name = audio_name
            log_debug(f"[SrcMgr] Creating audio capture: {source_name}")
            self.create_audio_capture(scene_name, source_name, audio_name)
            time.sleep(0.3)

        # Step 9: Verify configuration
        self.verify_and_fix_input_settings(scene_name, profile_config)

        log_success(f"[SrcMgr] Profile configured: {profile_name}")
        return True

    # =========================================================================
    # ISO RECORDING
    # =========================================================================

    def add_iso_recording_filter(
        self,
        source_name: str,
        record_path: str,
        filename: Optional[str] = None
    ) -> bool:
        """
        Add Source Record filter to a source for ISO recording.
        """
        if not self.is_source_record_plugin_installed():
            log_error("Cannot add ISO filter: Source Record plugin not installed")
            return False

        # Create safe filename from source name
        if filename is None:
            filename = source_name.replace(" ", "_").replace("/", "-").replace("\\", "-")

        # Ensure path uses forward slashes (OBS preference)
        record_path = record_path.replace("\\", "/")

        # Source Record plugin settings:
        # - record_mode: 3 = OUTPUT_MODE_RECORDING (records when OBS is recording)
        # - path: directory path (not full file path!)
        # - filename_formatting: the filename template without extension
        # - rec_format: container format (mov for better compatibility)
        filter_settings = {
            "record_mode": 3,  # OUTPUT_MODE_RECORDING - sync with OBS recording
            "path": record_path,
            "filename_formatting": filename,
            "rec_format": "mov"  # Use mov for better compatibility
        }

        # First try to remove existing filter (may not exist, that's okay)
        remove_response = self.ws.remove_source_filter(source_name, ISO_FILTER_NAME)
        if remove_response.success:
            log_debug(f"Removed existing ISO filter from: {source_name}")
        time.sleep(0.2)

        response = self.ws.create_source_filter(
            source_name=source_name,
            filter_name=ISO_FILTER_NAME,
            filter_kind=SOURCE_RECORD_FILTER_KIND,
            filter_settings=filter_settings
        )

        if response.success:
            log_info(f"Added ISO recording filter to: {source_name}")
            return True
        else:
            log_error(f"Failed to add ISO filter to {source_name}: {response.error_message}")
            return False

    def enable_iso_recording(self, scene_name: str, record_path: str) -> bool:
        """
        Enable ISO recording for all sources in a scene.
        - Video sources (displays, cameras): Use Source Record filter
        - Audio sources (mics): Use multi-track audio recording

        Source Record plugin doesn't support audio-only sources (wasapi_input_capture),
        so we configure those to separate audio tracks instead.
        """
        log_info("=" * 50)
        log_info("CONFIGURING ISO RECORDING")
        log_info("=" * 50)
        log_info(f"Scene: {scene_name}")
        log_info(f"Record path: {record_path}")

        # Check for Source Record plugin
        plugin_installed = self.is_source_record_plugin_installed()
        if not plugin_installed:
            log_error("SOURCE RECORD PLUGIN NOT INSTALLED!")
            log_error("ISO recording for video sources will NOT work!")
            log_error("Install from: https://obsproject.com/forum/resources/source-record.1285/")
            log_warning("Continuing with multi-track audio only...")

        response = self.ws.get_scene_item_list(scene_name)
        if not response.success:
            log_error(f"Failed to get scene items: {response.error_message}")
            return False

        items = response.data.get("sceneItems", [])
        log_info(f"Found {len(items)} items in scene")

        # Separate video and audio sources
        video_sources = []
        audio_sources = []

        for item in items:
            source_name = item.get("sourceName", "")
            # Check if this is an audio-only source (mic)
            # Note: Cameras with built-in mics are handled separately
            if source_name.lower().startswith("mic") or source_name.lower() == "microphone":
                audio_sources.append(source_name)
            else:
                video_sources.append(source_name)

        log_info(f"Video sources: {len(video_sources)}")
        log_info(f"Audio sources: {len(audio_sources)}")

        # Configure video sources with Source Record plugin
        video_success = 0
        if plugin_installed and video_sources:
            log_info("\n--- Configuring video sources with Source Record ---")
            for source_name in video_sources:
                log_debug(f"Adding ISO filter to: {source_name}")
                if self.add_iso_recording_filter(source_name, record_path):
                    video_success += 1
                else:
                    log_warning(f"Failed to add ISO filter to: {source_name}")
                time.sleep(0.3)
            log_info(f"Video ISO configured: {video_success}/{len(video_sources)}")

        # Configure audio sources with multi-track recording
        audio_success = 0
        if audio_sources:
            log_info("\n--- Configuring audio sources with multi-track recording ---")
            if self.configure_audio_tracks(audio_sources):
                audio_success = len(audio_sources)
            log_info(f"Audio tracks configured: {audio_success}/{len(audio_sources)}")

        log_info("=" * 50)
        total_sources = len(video_sources) + len(audio_sources)
        total_success = video_success + (1 if audio_success > 0 else 0)

        if video_success == len(video_sources) and audio_success > 0:
            log_success(f"ISO RECORDING FULLY CONFIGURED")
            log_info(f"  - Video sources: {video_success} with Source Record filters")
            log_info(f"  - Audio sources: {audio_success} with multi-track recording")
        elif video_success > 0 or audio_success > 0:
            log_warning(f"ISO RECORDING PARTIALLY CONFIGURED")
            log_info(f"  - Video sources: {video_success}/{len(video_sources)}")
            log_info(f"  - Audio sources: {audio_success}/{len(audio_sources)}")
        else:
            log_error("ISO RECORDING FAILED: No sources configured")

        log_info(f"Video files will be saved to: {record_path}")
        log_info(f"Audio will be in tracks 1-{min(len(audio_sources), 6)} of main recording")
        log_info("=" * 50)

        return video_success > 0 or audio_success > 0

    def disable_iso_recording(self, scene_name: str) -> bool:
        """
        Remove ISO recording filters from all sources in a scene.
        """
        response = self.ws.get_scene_item_list(scene_name)
        if not response.success:
            return False

        items = response.data.get("sceneItems", [])
        for item in items:
            source_name = item.get("sourceName")
            if source_name:
                self.ws.remove_source_filter(source_name, ISO_FILTER_NAME)

        log_info(f"Disabled ISO recording for scene: {scene_name}")
        return True

    # =========================================================================
    # MULTI-TRACK AUDIO RECORDING
    # =========================================================================

    def configure_audio_tracks(self, audio_sources: List[str]) -> bool:
        """
        Configure each audio source to output to a separate audio track.
        Track 1 is typically for the composite mix.
        Audio sources will be assigned to tracks 2-8.

        Source Record plugin doesn't support audio-only sources, so we use
        OBS's built-in multi-track recording for microphones.
        """
        log_info("=" * 50)
        log_info("CONFIGURING MULTI-TRACK AUDIO")
        log_info("=" * 50)
        log_info(f"Audio sources: {len(audio_sources)}")

        if len(audio_sources) > 6:
            log_warning(f"OBS supports 6 audio tracks, but {len(audio_sources)} audio sources configured")
            log_warning("Only first 6 audio sources will have dedicated tracks")

        success_count = 0
        for idx, source_name in enumerate(audio_sources[:6]):  # Max 6 tracks (tracks 1-6)
            # Assign this source to its own track (track idx+1)
            # Track mapping: {"1": True, "2": False, ...}
            track_config = {}
            for t in range(1, 7):  # Tracks 1-6
                # Each audio source outputs ONLY to its assigned track
                track_config[str(t)] = (t == idx + 1)

            log_debug(f"Setting {source_name} -> Track {idx + 1}")
            response = self.ws.set_input_audio_tracks(source_name, track_config)

            if response.success:
                log_info(f"Configured {source_name} -> Track {idx + 1}")
                success_count += 1
            else:
                log_warning(f"Failed to configure audio track for {source_name}: {response.error_message}")

        log_info("=" * 50)
        if success_count == len(audio_sources[:6]):
            log_success(f"AUDIO TRACKS CONFIGURED: {success_count} sources")
        else:
            log_warning(f"AUDIO TRACKS PARTIALLY CONFIGURED: {success_count}/{len(audio_sources[:6])}")
        log_info("=" * 50)

        return success_count > 0

    def get_audio_source_track_mapping(self, scene_name: str) -> dict:
        """
        Get the mapping of audio source names to their track numbers.
        Returns dict like {"Mic 1": 1, "Mic 2": 2, ...}
        """
        mapping = {}
        response = self.ws.get_scene_item_list(scene_name)
        if not response.success:
            return mapping

        items = response.data.get("sceneItems", [])
        track_num = 1

        for item in items:
            source_name = item.get("sourceName", "")
            # Check if this is an audio-only source (mic)
            if source_name.lower().startswith("mic") or "audio" in source_name.lower():
                # Get current track assignment
                track_response = self.ws.get_input_audio_tracks(source_name)
                if track_response.success:
                    tracks = track_response.data.get("inputAudioTracks", {})
                    # Find which track is enabled
                    for t, enabled in tracks.items():
                        if enabled:
                            mapping[source_name] = int(t)
                            break
                    else:
                        # No specific track, assign default
                        mapping[source_name] = track_num
                        track_num += 1
                else:
                    mapping[source_name] = track_num
                    track_num += 1

        return mapping
