"""
Main Window for Tutorial Recorder.
Shows in the taskbar like a regular Windows app.
"""

import threading
import traceback
import tkinter as tk
from typing import Optional

try:
    import customtkinter as ctk
    CTK_AVAILABLE = True
    print("[DEBUG] CustomTkinter loaded successfully")
except ImportError as e:
    CTK_AVAILABLE = False
    ctk = None
    print(f"[DEBUG] CustomTkinter not available: {e}")

from ..core.recording_manager import RecordingState
from ..utils.logger import log_info, log_error, log_debug


class MainWindow:
    """
    Main application window.
    Shows in taskbar, provides recording controls.
    """

    def __init__(self, app):
        print("[DEBUG] MainWindow.__init__ starting")
        self.app = app
        self._recording = False
        self._status_text = "Ready"

        try:
            self._create_window()
            print("[DEBUG] Window created successfully")
        except Exception as e:
            print(f"[ERROR] Failed to create window: {e}")
            traceback.print_exc()
            raise

        try:
            self._setup_callbacks()
            print("[DEBUG] Callbacks set up successfully")
        except Exception as e:
            print(f"[ERROR] Failed to setup callbacks: {e}")
            traceback.print_exc()

        # Auto-check OBS connection in background
        self._start_obs_check()

        print("[DEBUG] MainWindow.__init__ complete")

    def _start_obs_check(self):
        """Start background OBS connection check."""
        def check_obs():
            from ..core.obs_websocket import OBSWebSocketSync
            import time

            # Wait a moment for UI to be ready
            time.sleep(0.5)

            self.window.after(0, lambda: self._set_status("Checking OBS...", "orange"))

            ws = OBSWebSocketSync()
            if ws.connect(max_retries=5, retry_delay=0.5):
                try:
                    version_resp = ws.get_version()
                    if version_resp.success:
                        obs_ver = version_resp.data.get("obsVersion", "unknown")
                        msg = f"OBS {obs_ver} Connected"
                        self.window.after(0, lambda: self._set_status(msg, "green"))
                        self.window.after(0, lambda: self._hide_test_button())
                    else:
                        self.window.after(0, lambda: self._set_status("Ready", "gray"))
                finally:
                    ws.disconnect()
            else:
                self.window.after(0, lambda: self._set_status("OBS not connected", "orange"))

        thread = threading.Thread(target=check_obs, daemon=True)
        thread.start()

    def _hide_test_button(self):
        """Hide the test button when connected."""
        try:
            if hasattr(self, 'test_button'):
                self.test_button.pack_forget()
        except Exception:
            pass

    def _create_window(self):
        """Create the main window."""
        print("[DEBUG] _create_window starting")

        if CTK_AVAILABLE:
            print("[DEBUG] Using CustomTkinter")
            try:
                ctk.set_appearance_mode("dark")
                print("[DEBUG] Set appearance mode to dark")
            except Exception as e:
                print(f"[WARNING] Failed to set appearance mode: {e}")

            try:
                ctk.set_default_color_theme("blue")
                print("[DEBUG] Set color theme to blue")
            except Exception as e:
                print(f"[WARNING] Failed to set color theme: {e}")

            self.window = ctk.CTk()
            print("[DEBUG] CTk window created")
        else:
            print("[DEBUG] Using standard Tkinter")
            self.window = tk.Tk()

        self.window.title("Tutorial Recorder")
        self.window.geometry("400x500")
        self.window.minsize(350, 400)
        print("[DEBUG] Window geometry set")

        # Set icon
        try:
            from pathlib import Path
            icon_path = Path(__file__).parent.parent.parent / "resources" / "icon.ico"
            print(f"[DEBUG] Looking for icon at: {icon_path}")
            if icon_path.exists():
                self.window.iconbitmap(str(icon_path))
                print("[DEBUG] Icon set successfully")
            else:
                print(f"[WARNING] Icon not found at: {icon_path}")
        except Exception as e:
            print(f"[WARNING] Failed to set icon: {e}")

        # Build UI
        print("[DEBUG] Building UI...")
        try:
            self._build_ui()
            print("[DEBUG] UI built successfully")
        except Exception as e:
            print(f"[ERROR] Failed to build UI: {e}")
            traceback.print_exc()
            raise

        # Handle close
        self.window.protocol("WM_DELETE_WINDOW", self._on_close)
        print("[DEBUG] _create_window complete")

    def _build_ui(self):
        """Build the UI components."""
        if CTK_AVAILABLE:
            self._build_ctk_ui()
        else:
            self._build_tk_ui()

    def _build_ctk_ui(self):
        """Build CustomTkinter UI."""
        print("[DEBUG] _build_ctk_ui starting")

        # Main container
        main_frame = ctk.CTkFrame(self.window)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)
        print("[DEBUG] Main frame created")

        # Title
        title = ctk.CTkLabel(
            main_frame,
            text="Tutorial Recorder",
            font=ctk.CTkFont(size=24, weight="bold")
        )
        title.pack(pady=(0, 10))
        print("[DEBUG] Title created")

        # Status indicator
        self.status_frame = ctk.CTkFrame(main_frame, fg_color=("gray85", "gray20"))
        self.status_frame.pack(fill="x", pady=10)

        self.status_dot = ctk.CTkLabel(
            self.status_frame,
            text="●",
            font=ctk.CTkFont(size=24),
            text_color="gray"
        )
        self.status_dot.pack(side="left", padx=15, pady=10)

        self.status_label = ctk.CTkLabel(
            self.status_frame,
            text="Ready",
            font=ctk.CTkFont(size=16)
        )
        self.status_label.pack(side="left", pady=10)
        print("[DEBUG] Status indicator created")

        # Test OBS Connection button
        self.test_button = ctk.CTkButton(
            self.status_frame,
            text="Test OBS",
            command=self._test_obs_connection,
            width=80,
            height=28,
            font=ctk.CTkFont(size=12),
            fg_color="gray40",
            hover_color="gray50"
        )
        self.test_button.pack(side="right", padx=10, pady=5)
        print("[DEBUG] Test OBS button created")

        # Profile selection
        profile_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        profile_frame.pack(fill="x", pady=15)

        ctk.CTkLabel(
            profile_frame,
            text="Profile:",
            font=ctk.CTkFont(size=14)
        ).pack(anchor="w")

        profiles = self.app.get_profile_names()
        print(f"[DEBUG] Available profiles: {profiles}")

        self.profile_var = ctk.StringVar(value=profiles[0] if profiles else "")
        self.profile_dropdown = ctk.CTkComboBox(
            profile_frame,
            values=profiles,
            variable=self.profile_var,
            width=340
        )
        self.profile_dropdown.pack(fill="x", pady=(5, 0))
        print("[DEBUG] Profile dropdown created")

        # Project name
        name_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        name_frame.pack(fill="x", pady=10)

        ctk.CTkLabel(
            name_frame,
            text="Project Name:",
            font=ctk.CTkFont(size=14)
        ).pack(anchor="w")

        self.name_var = ctk.StringVar()
        self.name_entry = ctk.CTkEntry(
            name_frame,
            textvariable=self.name_var,
            placeholder_text="Enter project name...",
            width=340
        )
        self.name_entry.pack(fill="x", pady=(5, 0))
        print("[DEBUG] Name entry created")

        # Big record button
        self.record_button = ctk.CTkButton(
            main_frame,
            text="Start Recording",
            command=self._toggle_recording,
            height=50,
            font=ctk.CTkFont(size=18, weight="bold"),
            fg_color="#dc3545",
            hover_color="#c82333"
        )
        self.record_button.pack(fill="x", pady=20)
        print("[DEBUG] Record button created")

        # Bottom buttons
        button_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        button_frame.pack(fill="x", pady=10)

        ctk.CTkButton(
            button_frame,
            text="Configure Profiles",
            command=self._configure_profiles,
            width=160
        ).pack(side="left")

        ctk.CTkButton(
            button_frame,
            text="Open Folder",
            command=self._open_folder,
            width=160
        ).pack(side="right")
        print("[DEBUG] Bottom buttons created")

        # OBS button
        ctk.CTkButton(
            main_frame,
            text="Open OBS",
            command=self._open_obs,
            fg_color="gray30",
            hover_color="gray40"
        ).pack(fill="x", pady=(10, 0))
        print("[DEBUG] OBS button created")

        print("[DEBUG] _build_ctk_ui complete")

    def _build_tk_ui(self):
        """Build standard Tkinter UI (fallback)."""
        print("[DEBUG] _build_tk_ui starting (fallback mode)")

        tk.Label(
            self.window,
            text="Tutorial Recorder",
            font=("Arial", 18, "bold")
        ).pack(pady=20)

        # Status
        self.status_label = tk.Label(
            self.window,
            text="● Ready",
            font=("Arial", 14)
        )
        self.status_label.pack(pady=10)

        # Profile
        tk.Label(self.window, text="Profile:").pack(pady=(20, 5))
        profiles = self.app.get_profile_names()
        self.profile_var = tk.StringVar(value=profiles[0] if profiles else "")
        from tkinter import ttk
        self.profile_dropdown = ttk.Combobox(
            self.window,
            textvariable=self.profile_var,
            values=profiles
        )
        self.profile_dropdown.pack()

        # Project name
        tk.Label(self.window, text="Project Name:").pack(pady=(20, 5))
        self.name_var = tk.StringVar()
        self.name_entry = tk.Entry(self.window, textvariable=self.name_var, width=40)
        self.name_entry.pack()

        # Record button
        self.record_button = tk.Button(
            self.window,
            text="Start Recording",
            command=self._toggle_recording,
            bg="red",
            fg="white",
            font=("Arial", 14, "bold")
        )
        self.record_button.pack(pady=30)

        print("[DEBUG] _build_tk_ui complete")

    def _setup_callbacks(self):
        """Set up state change callbacks."""
        self.app.add_state_callback(self._on_state_change)

    def _on_state_change(self, state: RecordingState):
        """Handle recording state changes."""
        print(f"[DEBUG] State changed to: {state}")
        self.window.after(0, lambda: self._update_ui_state(state))

    def _update_ui_state(self, state: RecordingState):
        """Update UI based on state."""
        print(f"[DEBUG] Updating UI for state: {state}")

        if state == RecordingState.RECORDING:
            self._recording = True
            self._set_status("Recording...", "red")
            if CTK_AVAILABLE:
                self.record_button.configure(
                    text="Stop Recording",
                    fg_color="#28a745",
                    hover_color="#218838",
                    state="normal"  # Re-enable button after starting
                )
            else:
                self.record_button.config(text="Stop Recording", bg="green", state="normal")
            self.profile_dropdown.configure(state="disabled")
            self.name_entry.configure(state="disabled")

        elif state == RecordingState.STARTING:
            self._set_status("Starting...", "orange")
            self.record_button.configure(state="disabled")

        elif state == RecordingState.STOPPING:
            self._set_status("Stopping...", "orange")
            self.record_button.configure(state="disabled")

        else:  # IDLE
            self._recording = False
            self._set_status("Ready", "gray")
            if CTK_AVAILABLE:
                self.record_button.configure(
                    text="Start Recording",
                    fg_color="#dc3545",
                    hover_color="#c82333",
                    state="normal"
                )
            else:
                self.record_button.config(text="Start Recording", bg="red", state="normal")
            self.profile_dropdown.configure(state="normal")
            self.name_entry.configure(state="normal")

    def _set_status(self, text: str, color: str):
        """Update status display."""
        print(f"[DEBUG] Setting status: {text} ({color})")
        self._status_text = text
        if CTK_AVAILABLE:
            self.status_label.configure(text=text)
            self.status_dot.configure(text_color=color)
        else:
            self.status_label.config(text=f"● {text}")

    def _test_obs_connection(self):
        """Test connection to OBS WebSocket."""
        print("[DEBUG] Testing OBS connection...")
        self._set_status("Testing OBS...", "orange")
        self.test_button.configure(state="disabled")

        def test_connection():
            from ..core.obs_websocket import OBSWebSocketSync
            ws = OBSWebSocketSync()

            # Quick test - only 3 retries
            print("[DEBUG] Attempting to connect to OBS (3 retries)...")
            if ws.connect(max_retries=3, retry_delay=0.5):
                try:
                    version_resp = ws.get_version()
                    if version_resp.success:
                        obs_ver = version_resp.data.get("obsVersion", "unknown")
                        msg = f"OBS {obs_ver} - Connected!"
                        print(f"[DEBUG] Connection successful: {msg}")
                        self.window.after(0, lambda: self._set_status(msg, "green"))
                    else:
                        print("[DEBUG] Connected but couldn't get version")
                        self.window.after(0, lambda: self._set_status("Connected to OBS", "green"))
                finally:
                    ws.disconnect()
            else:
                print("[DEBUG] Connection failed")
                self.window.after(0, lambda: self._set_status("OBS not connected - Enable WebSocket!", "red"))
                self.window.after(0, lambda: self._show_websocket_help())

            self.window.after(0, lambda: self.test_button.configure(state="normal"))

        # Run in thread to not block UI
        import threading
        thread = threading.Thread(target=test_connection, daemon=True)
        thread.start()

    def _show_error_dialog(self, title: str, message: str):
        """Show an error dialog to the user."""
        print(f"[ERROR DIALOG] {title}: {message}")
        self._set_status("Error - see details", "red")

        try:
            if CTK_AVAILABLE:
                dialog = ctk.CTkToplevel(self.window)
                dialog.title(title)
                dialog.geometry("500x250")
                dialog.transient(self.window)
                dialog.grab_set()

                frame = ctk.CTkFrame(dialog)
                frame.pack(fill="both", expand=True, padx=20, pady=20)

                ctk.CTkLabel(
                    frame,
                    text=title,
                    font=ctk.CTkFont(size=18, weight="bold"),
                    text_color="red"
                ).pack(pady=(0, 15))

                # Scrollable text for long error messages
                textbox = ctk.CTkTextbox(frame, width=440, height=120)
                textbox.pack(pady=10)
                textbox.insert("1.0", message)
                textbox.configure(state="disabled")

                ctk.CTkButton(
                    frame,
                    text="OK",
                    command=dialog.destroy,
                    width=100
                ).pack(pady=10)
            else:
                from tkinter import messagebox
                messagebox.showerror(title, message)
        except Exception as e:
            print(f"[ERROR] Failed to show error dialog: {e}")

    def _show_websocket_help(self):
        """Show help for enabling WebSocket in OBS."""
        try:
            if CTK_AVAILABLE:
                dialog = ctk.CTkToplevel(self.window)
                dialog.title("OBS WebSocket Not Enabled")
                dialog.geometry("450x300")
                dialog.transient(self.window)
                dialog.grab_set()

                frame = ctk.CTkFrame(dialog)
                frame.pack(fill="both", expand=True, padx=20, pady=20)

                ctk.CTkLabel(
                    frame,
                    text="OBS WebSocket Not Enabled",
                    font=ctk.CTkFont(size=18, weight="bold")
                ).pack(pady=(0, 15))

                help_text = """To enable WebSocket in OBS:

1. Open OBS Studio
2. Go to Tools → WebSocket Server Settings
3. Check "Enable WebSocket Server"
4. Uncheck "Enable Authentication"
5. Make sure Port is 4455 (default)
6. Click OK

Then click "Test OBS" again to verify."""

                ctk.CTkLabel(
                    frame,
                    text=help_text,
                    font=ctk.CTkFont(size=13),
                    justify="left"
                ).pack(pady=10)

                ctk.CTkButton(
                    frame,
                    text="Open OBS",
                    command=lambda: (self._open_obs(), dialog.destroy()),
                    width=120
                ).pack(pady=15)

        except Exception as e:
            print(f"[ERROR] Failed to show help dialog: {e}")

    def _toggle_recording(self):
        """Toggle recording on/off."""
        print(f"[DEBUG] Toggle recording - currently recording: {self._recording}")
        if self._recording:
            self._stop_recording()
        else:
            self._start_recording()

    def _start_recording(self):
        """Start recording."""
        project_name = self.name_var.get().strip()
        profile_name = self.profile_var.get()

        print(f"[DEBUG] Start recording - project: '{project_name}', profile: '{profile_name}'")

        if not project_name:
            print("[WARNING] No project name entered")
            if CTK_AVAILABLE:
                self.name_entry.configure(border_color="red")
                self.window.after(2000, lambda: self.name_entry.configure(border_color=None))
            self._set_status("Enter a project name", "red")
            return

        if not profile_name:
            print("[WARNING] No profile selected")
            self._set_status("Select a profile", "red")
            return

        log_info(f"Starting recording: {project_name} with {profile_name}")

        def on_progress(msg: str):
            print(f"[PROGRESS] {msg}")
            self.window.after(0, lambda: self._set_status(msg, "orange"))

        # Start recording in a thread to not block UI
        def do_start():
            success = self.app.start_recording(project_name, profile_name, on_progress)
            if not success:
                # Show error message from recording manager
                error = self.app.get_last_error()
                if error:
                    self.window.after(0, lambda: self._show_error_dialog("Recording Failed", error))
                else:
                    self.window.after(0, lambda: self._set_status("Recording failed", "red"))

        import threading
        thread = threading.Thread(target=do_start, daemon=True)
        thread.start()

    def _stop_recording(self):
        """Stop recording."""
        print("[DEBUG] Stop recording called")
        log_info("Stopping recording")

        def on_progress(msg: str):
            print(f"[PROGRESS] {msg}")
            self.window.after(0, lambda: self._set_status(msg, "orange"))

        # Stop recording in a thread to not block UI
        def do_stop():
            self.app.stop_recording(on_progress)

        import threading
        thread = threading.Thread(target=do_stop, daemon=True)
        thread.start()

    def _configure_profiles(self):
        """Open profile configuration."""
        print("[DEBUG] Configure profiles clicked")
        from .profile_setup import ProfileListDialog, ProfileSetupDialog

        def on_profile_selected(profile_name: str):
            print(f"[DEBUG] Profile selected for configuration: {profile_name}")
            profile = self.app.get_profile(profile_name)
            if not profile:
                from ..utils.config import ProfileConfiguration
                profile = ProfileConfiguration(
                    profile_name=profile_name,
                    displays=[],
                    cameras=[],
                    audio_inputs=[],
                    is_configured=False
                )

            self.app.refresh_devices()

            def on_save(config):
                print(f"[DEBUG] Saving profile config: {config.profile_name}")
                self.app.save_profile(config)

            setup_dialog = ProfileSetupDialog(
                profile=profile,
                available_displays=self.app.get_available_displays(),
                available_cameras=self.app.get_available_cameras(),
                available_audio=self.app.get_available_audio_inputs(),
                on_save=on_save,
                parent=self.window
            )
            setup_dialog.show()

        dialog = ProfileListDialog(
            profiles=self.app.get_profile_names(),
            on_select=on_profile_selected,
            parent=self.window
        )
        dialog.show()

    def _open_folder(self):
        """Open recordings folder."""
        print("[DEBUG] Open folder clicked")
        self.app.open_recordings_folder()

    def _open_obs(self):
        """Open OBS."""
        print("[DEBUG] Open OBS clicked")
        self.app.open_obs()

    def _on_close(self):
        """Handle window close."""
        print("[DEBUG] Window close requested")
        if self._recording:
            # Confirm before closing while recording
            if CTK_AVAILABLE:
                from tkinter import messagebox
                if not messagebox.askyesno(
                    "Recording Active",
                    "Recording is in progress. Stop recording and quit?"
                ):
                    return
            self.app.stop_recording()

        print("[DEBUG] Closing window")
        self.window.destroy()

    def run(self):
        """Run the main window."""
        print("[DEBUG] Starting main window loop")
        log_info("Tutorial Recorder window opened")
        self.window.mainloop()
        print("[DEBUG] Main window loop ended")
