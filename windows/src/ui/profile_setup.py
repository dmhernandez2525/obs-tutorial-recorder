"""
Profile Setup Dialog.
Allows configuring displays, cameras, and audio for profiles.
"""

import tkinter as tk
from tkinter import ttk
from typing import Callable, List, Optional

try:
    import customtkinter as ctk
    CTK_AVAILABLE = True
except ImportError:
    CTK_AVAILABLE = False
    ctk = None

from ..utils.config import ProfileConfiguration
from ..utils.logger import log_info


class ProfileSetupDialog:
    """
    Dialog for configuring recording profiles.
    Supports up to 10 cameras for the PC-10Cameras profile.
    """

    def __init__(
        self,
        profile: ProfileConfiguration,
        available_displays: List[str],
        available_cameras: List[str],
        available_audio: List[str],
        on_save: Callable[[ProfileConfiguration], None],
        parent: Optional[tk.Tk] = None
    ):
        self.profile = profile
        self.available_displays = available_displays
        self.available_cameras = available_cameras
        self.available_audio = available_audio
        self.on_save = on_save

        # Checkbox variables
        self.display_vars = {}
        self.camera_vars = {}
        self.audio_vars = {}

        self._create_window(parent)

    def _create_window(self, parent: Optional[tk.Tk]):
        """Create the setup window."""
        if CTK_AVAILABLE:
            self._create_ctk_window(parent)
        else:
            self._create_tk_window(parent)

    def _create_ctk_window(self, parent: Optional[tk.Tk]):
        """Create CustomTkinter window."""
        if parent:
            self.window = ctk.CTkToplevel(parent)
        else:
            self.window = ctk.CTk()

        self.window.title(f"Configure Profile: {self.profile.profile_name}")
        self.window.geometry("600x700")
        self.window.resizable(True, True)

        # Center on screen
        self.window.update_idletasks()
        x = (self.window.winfo_screenwidth() - 600) // 2
        y = (self.window.winfo_screenheight() - 700) // 2
        self.window.geometry(f"+{x}+{y}")

        # Scrollable frame
        main_frame = ctk.CTkScrollableFrame(self.window)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Title
        title = ctk.CTkLabel(
            main_frame,
            text=f"Configure: {self.profile.profile_name}",
            font=ctk.CTkFont(size=20, weight="bold")
        )
        title.pack(pady=(0, 20))

        # Displays section
        self._create_section(
            main_frame,
            "Displays",
            self.available_displays,
            self.profile.displays,
            self.display_vars
        )

        # Cameras section
        self._create_section(
            main_frame,
            "Cameras",
            self.available_cameras,
            self.profile.cameras,
            self.camera_vars
        )

        # Audio section
        self._create_section(
            main_frame,
            "Audio Inputs",
            self.available_audio,
            self.profile.audio_inputs,
            self.audio_vars
        )

        # Buttons
        button_frame = ctk.CTkFrame(self.window, fg_color="transparent")
        button_frame.pack(fill="x", padx=20, pady=20)

        cancel_btn = ctk.CTkButton(
            button_frame,
            text="Cancel",
            command=self._on_cancel,
            fg_color="gray",
            width=120
        )
        cancel_btn.pack(side="left")

        save_btn = ctk.CTkButton(
            button_frame,
            text="Save Configuration",
            command=self._on_save,
            width=150
        )
        save_btn.pack(side="right")

    def _create_section(
        self,
        parent,
        title: str,
        available: List[str],
        selected: List[str],
        var_dict: dict
    ):
        """Create a section with checkboxes."""
        if not CTK_AVAILABLE:
            return

        # Section label
        label = ctk.CTkLabel(
            parent,
            text=title,
            font=ctk.CTkFont(size=16, weight="bold")
        )
        label.pack(anchor="w", pady=(20, 10))

        # Frame for checkboxes
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 10))

        if not available:
            no_devices = ctk.CTkLabel(frame, text="No devices found")
            no_devices.pack(pady=10)
            return

        for item in available:
            var = ctk.BooleanVar(value=item in selected)
            var_dict[item] = var

            checkbox = ctk.CTkCheckBox(
                frame,
                text=item,
                variable=var,
                font=ctk.CTkFont(size=14)
            )
            checkbox.pack(anchor="w", padx=20, pady=5)

    def _create_tk_window(self, parent: Optional[tk.Tk]):
        """Create standard Tkinter window (fallback)."""
        if parent:
            self.window = tk.Toplevel(parent)
        else:
            self.window = tk.Tk()

        self.window.title(f"Configure Profile: {self.profile.profile_name}")
        self.window.geometry("500x600")

        # Displays
        tk.Label(self.window, text="Displays:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        for display in self.available_displays:
            var = tk.BooleanVar(value=display in self.profile.displays)
            self.display_vars[display] = var
            ttk.Checkbutton(self.window, text=display, variable=var).pack(anchor="w", padx=40)

        # Cameras
        tk.Label(self.window, text="Cameras:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        for camera in self.available_cameras:
            var = tk.BooleanVar(value=camera in self.profile.cameras)
            self.camera_vars[camera] = var
            ttk.Checkbutton(self.window, text=camera, variable=var).pack(anchor="w", padx=40)

        # Audio
        tk.Label(self.window, text="Audio Inputs:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        for audio in self.available_audio:
            var = tk.BooleanVar(value=audio in self.profile.audio_inputs)
            self.audio_vars[audio] = var
            ttk.Checkbutton(self.window, text=audio, variable=var).pack(anchor="w", padx=40)

        # Buttons
        button_frame = tk.Frame(self.window)
        button_frame.pack(pady=30)
        ttk.Button(button_frame, text="Cancel", command=self._on_cancel).pack(side="left", padx=10)
        ttk.Button(button_frame, text="Save", command=self._on_save).pack(side="left", padx=10)

    def _on_save(self):
        """Handle save button click."""
        # Collect selected items
        selected_displays = [d for d, var in self.display_vars.items() if var.get()]
        selected_cameras = [c for c, var in self.camera_vars.items() if var.get()]
        selected_audio = [a for a, var in self.audio_vars.items() if var.get()]

        # Update profile
        self.profile.displays = selected_displays
        self.profile.cameras = selected_cameras
        self.profile.audio_inputs = selected_audio
        self.profile.is_configured = True

        log_info(f"Profile configured: {self.profile.profile_name}")
        log_info(f"  Displays: {selected_displays}")
        log_info(f"  Cameras: {selected_cameras}")
        log_info(f"  Audio: {selected_audio}")

        self.window.destroy()

        if self.on_save:
            self.on_save(self.profile)

    def _on_cancel(self):
        """Handle cancel button click."""
        self.window.destroy()

    def show(self):
        """Show the dialog."""
        self.window.grab_set()
        self.window.wait_window()

    def run(self):
        """Run the dialog (standalone)."""
        self.window.mainloop()


class ProfileListDialog:
    """
    Dialog showing list of profiles to configure.
    """

    def __init__(
        self,
        profiles: List[str],
        on_select: Callable[[str], None],
        parent: Optional[tk.Tk] = None
    ):
        self.profiles = profiles
        self.on_select = on_select

        self._create_window(parent)

    def _create_window(self, parent: Optional[tk.Tk]):
        """Create the window."""
        if CTK_AVAILABLE:
            if parent:
                self.window = ctk.CTkToplevel(parent)
            else:
                self.window = ctk.CTk()

            self.window.title("Configure Profiles")
            self.window.geometry("400x400")

            # Center on screen
            self.window.update_idletasks()
            x = (self.window.winfo_screenwidth() - 400) // 2
            y = (self.window.winfo_screenheight() - 400) // 2
            self.window.geometry(f"+{x}+{y}")

            main_frame = ctk.CTkFrame(self.window)
            main_frame.pack(fill="both", expand=True, padx=20, pady=20)

            title = ctk.CTkLabel(
                main_frame,
                text="Select Profile to Configure",
                font=ctk.CTkFont(size=18, weight="bold")
            )
            title.pack(pady=(0, 20))

            for profile in self.profiles:
                btn = ctk.CTkButton(
                    main_frame,
                    text=profile,
                    command=lambda p=profile: self._on_profile_selected(p),
                    width=300,
                    height=40
                )
                btn.pack(pady=5)

            close_btn = ctk.CTkButton(
                main_frame,
                text="Close",
                command=self.window.destroy,
                fg_color="gray",
                width=100
            )
            close_btn.pack(pady=(30, 0))

        else:
            if parent:
                self.window = tk.Toplevel(parent)
            else:
                self.window = tk.Tk()

            self.window.title("Configure Profiles")
            self.window.geometry("300x300")

            for profile in self.profiles:
                ttk.Button(
                    self.window,
                    text=profile,
                    command=lambda p=profile: self._on_profile_selected(p)
                ).pack(pady=10)

            ttk.Button(self.window, text="Close", command=self.window.destroy).pack(pady=20)

    def _on_profile_selected(self, profile: str):
        """Handle profile selection."""
        self.window.destroy()
        if self.on_select:
            self.on_select(profile)

    def show(self):
        """Show the dialog."""
        self.window.grab_set()
        self.window.wait_window()

    def run(self):
        """Run the dialog."""
        self.window.mainloop()
