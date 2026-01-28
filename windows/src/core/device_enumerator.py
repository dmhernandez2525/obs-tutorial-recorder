"""
Windows device enumeration for cameras, audio inputs, and displays.
Uses DirectShow and Windows APIs.
"""

import subprocess
from dataclasses import dataclass
from typing import List, Optional, Tuple
import ctypes
from ctypes import wintypes

from ..utils.logger import log_info, log_error, log_debug, log_warning


@dataclass
class VideoDevice:
    """Represents a video capture device (camera)."""
    name: str
    device_id: str  # For OBS dshow_input
    index: int

    def __str__(self):
        return self.name


@dataclass
class AudioDevice:
    """Represents an audio input device (microphone)."""
    name: str
    device_id: str  # For OBS wasapi_input_capture
    index: int

    def __str__(self):
        return self.name


@dataclass
class DisplayInfo:
    """Represents a display/monitor."""
    name: str
    index: int  # 0-based index for OBS
    width: int
    height: int
    is_primary: bool

    def __str__(self):
        return f"{self.name} ({self.width}x{self.height})"


class DeviceEnumerator:
    """Enumerates cameras, audio devices, and displays on Windows."""

    def __init__(self):
        self._cameras: Optional[List[VideoDevice]] = None
        self._audio_inputs: Optional[List[AudioDevice]] = None
        self._displays: Optional[List[DisplayInfo]] = None

    def refresh(self):
        """Force refresh of all device lists."""
        self._cameras = None
        self._audio_inputs = None
        self._displays = None

    def get_cameras(self, force_refresh: bool = False) -> List[VideoDevice]:
        """
        Get list of available video capture devices.
        Uses multiple methods for reliability.
        """
        if self._cameras is not None and not force_refresh:
            return self._cameras

        cameras = []

        # Method 1: Try using ffmpeg to enumerate DirectShow devices
        try:
            result = subprocess.run(
                ['ffmpeg', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
                capture_output=True,
                text=True,
                timeout=10
            )
            # Parse stderr for video devices
            lines = result.stderr.split('\n')
            in_video_section = False
            index = 0

            for line in lines:
                if 'DirectShow video devices' in line:
                    in_video_section = True
                    continue
                elif 'DirectShow audio devices' in line:
                    in_video_section = False
                    continue

                if in_video_section and '"' in line:
                    # Extract device name between quotes
                    start = line.find('"') + 1
                    end = line.rfind('"')
                    if start < end:
                        name = line[start:end]
                        if name and not name.startswith('@device'):
                            cameras.append(VideoDevice(
                                name=name,
                                device_id=name,  # DirectShow uses name as ID
                                index=index
                            ))
                            index += 1
                            log_debug(f"Found camera: {name}")

        except FileNotFoundError:
            log_warning("ffmpeg not found, trying alternative method")
        except subprocess.TimeoutExpired:
            log_warning("ffmpeg device enumeration timed out")
        except Exception as e:
            log_warning(f"ffmpeg enumeration failed: {e}")

        # Method 2: Fallback using PowerShell/WMI
        if not cameras:
            try:
                result = subprocess.run(
                    ['powershell', '-Command',
                     'Get-CimInstance Win32_PnPEntity | Where-Object { $_.Caption -match "camera|webcam|video" } | Select-Object -ExpandProperty Caption'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0:
                    for idx, line in enumerate(result.stdout.strip().split('\n')):
                        name = line.strip()
                        if name:
                            cameras.append(VideoDevice(
                                name=name,
                                device_id=name,
                                index=idx
                            ))
                            log_debug(f"Found camera (WMI): {name}")
            except Exception as e:
                log_warning(f"WMI camera enumeration failed: {e}")

        # Method 3: Use OpenCV as last resort
        if not cameras:
            try:
                import cv2
                for i in range(10):
                    cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)
                    if cap.isOpened():
                        cameras.append(VideoDevice(
                            name=f"Camera {i}",
                            device_id=str(i),
                            index=i
                        ))
                        cap.release()
                        log_debug(f"Found camera (OpenCV): Camera {i}")
            except ImportError:
                log_debug("OpenCV not available for camera enumeration")
            except Exception as e:
                log_warning(f"OpenCV camera enumeration failed: {e}")

        # If still no cameras, add placeholders for 7-camera setup
        if not cameras:
            log_warning("No cameras detected, adding placeholders")
            for i in range(7):
                cameras.append(VideoDevice(
                    name=f"Camera {i + 1}",
                    device_id=f"Camera {i + 1}",
                    index=i
                ))

        self._cameras = cameras
        log_info(f"Found {len(cameras)} camera(s)")
        return cameras

    def get_audio_inputs(self, force_refresh: bool = False) -> List[AudioDevice]:
        """
        Get list of available audio input devices.
        """
        if self._audio_inputs is not None and not force_refresh:
            return self._audio_inputs

        audio_devices = []

        # Method 1: Try using ffmpeg
        try:
            result = subprocess.run(
                ['ffmpeg', '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
                capture_output=True,
                text=True,
                timeout=10
            )
            lines = result.stderr.split('\n')
            in_audio_section = False
            index = 0

            for line in lines:
                if 'DirectShow audio devices' in line:
                    in_audio_section = True
                    continue
                elif in_audio_section and 'Alternative name' in line:
                    continue

                if in_audio_section and '"' in line:
                    start = line.find('"') + 1
                    end = line.rfind('"')
                    if start < end:
                        name = line[start:end]
                        if name and not name.startswith('@device'):
                            audio_devices.append(AudioDevice(
                                name=name,
                                device_id=name,
                                index=index
                            ))
                            index += 1
                            log_debug(f"Found audio device: {name}")

        except FileNotFoundError:
            log_warning("ffmpeg not found for audio enumeration")
        except Exception as e:
            log_warning(f"ffmpeg audio enumeration failed: {e}")

        # Method 2: Try PyAudio
        if not audio_devices:
            try:
                import pyaudio
                p = pyaudio.PyAudio()
                for i in range(p.get_device_count()):
                    info = p.get_device_info_by_index(i)
                    if info.get('maxInputChannels', 0) > 0:
                        name = info.get('name', f'Audio Device {i}')
                        audio_devices.append(AudioDevice(
                            name=name,
                            device_id=name,
                            index=i
                        ))
                        log_debug(f"Found audio device (PyAudio): {name}")
                p.terminate()
            except ImportError:
                log_debug("PyAudio not available")
            except Exception as e:
                log_warning(f"PyAudio enumeration failed: {e}")

        # Method 3: PowerShell/WMI
        if not audio_devices:
            try:
                result = subprocess.run(
                    ['powershell', '-Command',
                     'Get-CimInstance Win32_SoundDevice | Select-Object -ExpandProperty Caption'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                if result.returncode == 0:
                    for idx, line in enumerate(result.stdout.strip().split('\n')):
                        name = line.strip()
                        if name:
                            audio_devices.append(AudioDevice(
                                name=name,
                                device_id=name,
                                index=idx
                            ))
            except Exception as e:
                log_warning(f"WMI audio enumeration failed: {e}")

        # Fallback to default
        if not audio_devices:
            audio_devices.append(AudioDevice(
                name="Default Microphone",
                device_id="default",
                index=0
            ))

        self._audio_inputs = audio_devices
        log_info(f"Found {len(audio_devices)} audio input(s)")
        return audio_devices

    def get_displays(self, force_refresh: bool = False) -> List[DisplayInfo]:
        """
        Get list of available displays/monitors.
        """
        if self._displays is not None and not force_refresh:
            return self._displays

        displays = []

        try:
            # Use ctypes to enumerate monitors
            user32 = ctypes.windll.user32

            # Get primary monitor
            primary_width = user32.GetSystemMetrics(0)  # SM_CXSCREEN
            primary_height = user32.GetSystemMetrics(1)  # SM_CYSCREEN

            # EnumDisplayMonitors callback
            MONITORENUMPROC = ctypes.WINFUNCTYPE(
                ctypes.c_bool,
                ctypes.c_ulong,
                ctypes.c_ulong,
                ctypes.POINTER(wintypes.RECT),
                ctypes.c_double
            )

            monitors = []

            def callback(hMonitor, hdcMonitor, lprcMonitor, dwData):
                rect = lprcMonitor.contents
                width = rect.right - rect.left
                height = rect.bottom - rect.top
                monitors.append({
                    'handle': hMonitor,
                    'left': rect.left,
                    'top': rect.top,
                    'width': width,
                    'height': height
                })
                return True

            user32.EnumDisplayMonitors(None, None, MONITORENUMPROC(callback), 0)

            # Sort by position (left to right, top to bottom)
            monitors.sort(key=lambda m: (m['top'], m['left']))

            for idx, mon in enumerate(monitors):
                is_primary = (mon['left'] == 0 and mon['top'] == 0 and
                              mon['width'] == primary_width and mon['height'] == primary_height)
                displays.append(DisplayInfo(
                    name=f"Display {idx + 1}",
                    index=idx,
                    width=mon['width'],
                    height=mon['height'],
                    is_primary=is_primary
                ))
                log_debug(f"Found display: Display {idx + 1} ({mon['width']}x{mon['height']})")

        except Exception as e:
            log_warning(f"Monitor enumeration failed: {e}")

        # Fallback to at least one display
        if not displays:
            try:
                user32 = ctypes.windll.user32
                width = user32.GetSystemMetrics(0)
                height = user32.GetSystemMetrics(1)
                displays.append(DisplayInfo(
                    name="Display 1",
                    index=0,
                    width=width,
                    height=height,
                    is_primary=True
                ))
            except Exception:
                displays.append(DisplayInfo(
                    name="Display 1",
                    index=0,
                    width=1920,
                    height=1080,
                    is_primary=True
                ))

        self._displays = displays
        log_info(f"Found {len(displays)} display(s)")
        return displays

    def get_camera_names(self) -> List[str]:
        """Get list of camera names."""
        return [cam.name for cam in self.get_cameras()]

    def get_audio_input_names(self) -> List[str]:
        """Get list of audio input names."""
        return [dev.name for dev in self.get_audio_inputs()]

    def get_display_names(self) -> List[str]:
        """Get list of display names."""
        return [disp.name for disp in self.get_displays()]

    def find_camera_by_name(self, name: str) -> Optional[VideoDevice]:
        """Find a camera by name (case-insensitive partial match)."""
        name_lower = name.lower()
        for cam in self.get_cameras():
            if name_lower in cam.name.lower() or cam.name.lower() in name_lower:
                return cam
        return None

    def find_audio_by_name(self, name: str) -> Optional[AudioDevice]:
        """Find an audio device by name (case-insensitive partial match)."""
        name_lower = name.lower()
        for dev in self.get_audio_inputs():
            if name_lower in dev.name.lower() or dev.name.lower() in name_lower:
                return dev
        return None


# Global device enumerator instance
_enumerator: Optional[DeviceEnumerator] = None


def get_device_enumerator() -> DeviceEnumerator:
    """Get the global device enumerator instance."""
    global _enumerator
    if _enumerator is None:
        _enumerator = DeviceEnumerator()
    return _enumerator
