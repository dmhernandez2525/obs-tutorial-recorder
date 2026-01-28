"""
System Tray integration for Windows.
Uses pystray for system tray icon and menu.
"""

import threading
from typing import Callable, Optional

try:
    import pystray
    from pystray import MenuItem as Item, Menu
    from PIL import Image, ImageDraw
    PYSTRAY_AVAILABLE = True
except ImportError:
    PYSTRAY_AVAILABLE = False
    pystray = None

from ..core.recording_manager import RecordingState
from ..utils.logger import log_info, log_error


def create_icon_image(color: str = "gray", size: int = 64) -> "Image.Image":
    """
    Create or load icon image.
    color: 'gray' for idle, 'red' for recording
    """
    if not PYSTRAY_AVAILABLE:
        return None

    # Try to load from file first
    from pathlib import Path
    resources_dir = Path(__file__).parent.parent.parent / "resources"

    if color == "red":
        icon_path = resources_dir / "icon_recording.ico"
    else:
        icon_path = resources_dir / "icon.ico"

    if icon_path.exists():
        try:
            return Image.open(icon_path)
        except Exception:
            pass

    # Fallback: create dynamically
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Circle colors
    if color == "red":
        fill_color = (220, 53, 69, 255)  # Red for recording
        outline_color = (180, 40, 50, 255)
    else:
        fill_color = (108, 117, 125, 255)  # Gray for idle
        outline_color = (80, 90, 100, 255)

    # Draw circle
    padding = 4
    draw.ellipse(
        [padding, padding, size - padding, size - padding],
        fill=fill_color,
        outline=outline_color,
        width=2
    )

    # Add inner dot for recording indicator
    if color == "red":
        inner_padding = size // 4
        draw.ellipse(
            [inner_padding, inner_padding, size - inner_padding, size - inner_padding],
            fill=(255, 255, 255, 200)
        )

    return image


class SystemTray:
    """
    System tray icon with dynamic menu.
    """

    def __init__(
        self,
        on_start_recording: Callable,
        on_stop_recording: Callable,
        on_configure_profiles: Callable,
        on_open_obs: Callable,
        on_open_folder: Callable,
        on_sync: Optional[Callable] = None,
        on_quit: Optional[Callable] = None,
    ):
        if not PYSTRAY_AVAILABLE:
            raise ImportError("pystray is not installed. Run: pip install pystray Pillow")

        self._on_start_recording = on_start_recording
        self._on_stop_recording = on_stop_recording
        self._on_configure_profiles = on_configure_profiles
        self._on_open_obs = on_open_obs
        self._on_open_folder = on_open_folder
        self._on_sync = on_sync
        self._on_quit = on_quit

        self._is_recording = False
        self._icon: Optional[pystray.Icon] = None
        self._thread: Optional[threading.Thread] = None

        # Create icons
        self._idle_icon = create_icon_image("gray")
        self._recording_icon = create_icon_image("red")

    def _build_menu(self) -> Menu:
        """Build the context menu based on current state."""
        if self._is_recording:
            return Menu(
                Item("Stop Recording", self._handle_stop_recording),
                Menu.SEPARATOR,
                Item("Open Project Folder", self._handle_open_folder),
                Menu.SEPARATOR,
                Item("Quit", self._handle_quit),
            )
        else:
            items = [
                Item("Start Recording...", self._handle_start_recording),
                Menu.SEPARATOR,
                Item("Configure Profiles...", self._handle_configure_profiles),
                Item("Open OBS", self._handle_open_obs),
                Item("Open Recordings Folder", self._handle_open_folder),
            ]

            if self._on_sync:
                items.append(Menu.SEPARATOR)
                items.append(Item("Sync Now", self._handle_sync))

            items.extend([
                Menu.SEPARATOR,
                Item("Quit", self._handle_quit),
            ])

            return Menu(*items)

    def _handle_start_recording(self, icon, item):
        """Handle start recording menu click."""
        try:
            self._on_start_recording()
        except Exception as e:
            log_error(f"Start recording handler error: {e}")

    def _handle_stop_recording(self, icon, item):
        """Handle stop recording menu click."""
        try:
            self._on_stop_recording()
        except Exception as e:
            log_error(f"Stop recording handler error: {e}")

    def _handle_configure_profiles(self, icon, item):
        """Handle configure profiles menu click."""
        try:
            self._on_configure_profiles()
        except Exception as e:
            log_error(f"Configure profiles handler error: {e}")

    def _handle_open_obs(self, icon, item):
        """Handle open OBS menu click."""
        try:
            self._on_open_obs()
        except Exception as e:
            log_error(f"Open OBS handler error: {e}")

    def _handle_open_folder(self, icon, item):
        """Handle open folder menu click."""
        try:
            self._on_open_folder()
        except Exception as e:
            log_error(f"Open folder handler error: {e}")

    def _handle_sync(self, icon, item):
        """Handle sync menu click."""
        if self._on_sync:
            try:
                self._on_sync()
            except Exception as e:
                log_error(f"Sync handler error: {e}")

    def _handle_quit(self, icon, item):
        """Handle quit menu click."""
        if self._on_quit:
            try:
                self._on_quit()
            except Exception as e:
                log_error(f"Quit handler error: {e}")
        self.stop()

    def set_recording_state(self, is_recording: bool):
        """Update the icon and menu based on recording state."""
        self._is_recording = is_recording

        if self._icon:
            # Update icon
            self._icon.icon = self._recording_icon if is_recording else self._idle_icon

            # Update tooltip
            status = "Recording..." if is_recording else "Ready"
            self._icon.title = f"Tutorial Recorder - {status}"

            # Update menu
            self._icon.menu = self._build_menu()

    def on_state_change(self, state: RecordingState):
        """Handle recording state changes."""
        self.set_recording_state(state == RecordingState.RECORDING)

    def start(self):
        """Start the system tray icon."""
        self._icon = pystray.Icon(
            "Tutorial Recorder",
            self._idle_icon,
            "Tutorial Recorder - Ready",
            menu=self._build_menu()
        )

        # Run in background thread
        self._thread = threading.Thread(target=self._icon.run, daemon=True)
        self._thread.start()
        log_info("System tray started")

    def stop(self):
        """Stop the system tray icon."""
        if self._icon:
            self._icon.stop()
            self._icon = None
        log_info("System tray stopped")

    def run(self):
        """Run the system tray (blocking)."""
        self._icon = pystray.Icon(
            "Tutorial Recorder",
            self._idle_icon,
            "Tutorial Recorder - Ready",
            menu=self._build_menu()
        )
        log_info("System tray running")
        self._icon.run()
