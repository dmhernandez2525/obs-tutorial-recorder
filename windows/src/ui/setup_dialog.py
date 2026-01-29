"""
Setup Dialog for OBS Tutorial Recorder.
Shows first-run setup wizard to install prerequisites.
"""

import threading
import tkinter as tk
from typing import Callable, Optional

try:
    import customtkinter as ctk
    CTK_AVAILABLE = True
except ImportError:
    CTK_AVAILABLE = False
    ctk = None

from ..core.setup_wizard import get_setup_wizard, SetupStatus
from ..utils.logger import log_info, log_error


class SetupDialog:
    """
    First-run setup wizard dialog.
    Checks and installs prerequisites.
    """

    def __init__(self, parent: Optional[tk.Tk] = None, on_complete: Optional[Callable[[], None]] = None):
        self.parent = parent
        self.on_complete = on_complete
        self.wizard = get_setup_wizard()
        self._installing = False

        self._create_window()
        self._check_status()

    def _create_window(self):
        """Create the setup dialog window."""
        if CTK_AVAILABLE:
            if self.parent:
                self.window = ctk.CTkToplevel(self.parent)
            else:
                self.window = ctk.CTk()
            ctk.set_appearance_mode("dark")
        else:
            if self.parent:
                self.window = tk.Toplevel(self.parent)
            else:
                self.window = tk.Tk()

        self.window.title("Tutorial Recorder Setup")
        self.window.geometry("550x600")
        self.window.resizable(False, False)

        if self.parent:
            self.window.transient(self.parent)
            self.window.grab_set()

        # Center window
        self.window.update_idletasks()
        x = (self.window.winfo_screenwidth() - 550) // 2
        y = (self.window.winfo_screenheight() - 600) // 2
        self.window.geometry(f"550x600+{x}+{y}")

        self._build_ui()

    def _build_ui(self):
        """Build the setup UI."""
        if CTK_AVAILABLE:
            self._build_ctk_ui()
        else:
            self._build_tk_ui()

    def _build_ctk_ui(self):
        """Build CustomTkinter UI."""
        # Main container
        main_frame = ctk.CTkFrame(self.window)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Title
        ctk.CTkLabel(
            main_frame,
            text="Welcome to Tutorial Recorder",
            font=ctk.CTkFont(size=22, weight="bold")
        ).pack(pady=(0, 5))

        ctk.CTkLabel(
            main_frame,
            text="Let's set up the required components",
            font=ctk.CTkFont(size=14),
            text_color="gray"
        ).pack(pady=(0, 20))

        # Status section
        self.status_frame = ctk.CTkFrame(main_frame)
        self.status_frame.pack(fill="x", pady=10)

        # Create status rows
        self.status_rows = {}
        components = [
            ("obs", "OBS Studio", "Required for recording"),
            ("websocket", "OBS WebSocket", "Required for app control"),
            ("ffmpeg", "FFmpeg", "Required for audio extraction"),
            ("source_record", "Source Record Plugin", "Required for ISO recording"),
        ]

        for key, name, desc in components:
            row = self._create_status_row(self.status_frame, name, desc)
            self.status_rows[key] = row

        # Progress section
        self.progress_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        self.progress_frame.pack(fill="x", pady=20)

        self.progress_label = ctk.CTkLabel(
            self.progress_frame,
            text="Checking system...",
            font=ctk.CTkFont(size=13)
        )
        self.progress_label.pack()

        self.progress_bar = ctk.CTkProgressBar(self.progress_frame, width=400)
        self.progress_bar.pack(pady=10)
        self.progress_bar.set(0)

        # Action buttons
        self.button_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        self.button_frame.pack(fill="x", pady=20)

        self.install_all_btn = ctk.CTkButton(
            self.button_frame,
            text="Install Missing Components",
            command=self._install_all,
            height=40,
            font=ctk.CTkFont(size=14, weight="bold"),
            fg_color="#28a745",
            hover_color="#218838"
        )
        self.install_all_btn.pack(fill="x", pady=5)

        self.websocket_btn = ctk.CTkButton(
            self.button_frame,
            text="Open OBS to Enable WebSocket",
            command=self._open_obs_for_websocket,
            height=35,
            fg_color="gray40",
            hover_color="gray50"
        )
        self.websocket_btn.pack(fill="x", pady=5)

        self.refresh_btn = ctk.CTkButton(
            self.button_frame,
            text="Refresh Status",
            command=self._check_status,
            height=35,
            fg_color="gray30",
            hover_color="gray40"
        )
        self.refresh_btn.pack(fill="x", pady=5)

        # Continue button (shown when ready)
        self.continue_btn = ctk.CTkButton(
            self.button_frame,
            text="Continue to App →",
            command=self._complete_setup,
            height=45,
            font=ctk.CTkFont(size=16, weight="bold"),
            fg_color="#007bff",
            hover_color="#0056b3"
        )
        # Hidden initially, shown when all ready

        # Info text
        self.info_label = ctk.CTkLabel(
            main_frame,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="gray",
            wraplength=480
        )
        self.info_label.pack(pady=10)

    def _build_tk_ui(self):
        """Build standard Tkinter UI (fallback)."""
        tk.Label(
            self.window,
            text="Tutorial Recorder Setup",
            font=("Arial", 18, "bold")
        ).pack(pady=20)

        self.status_label = tk.Label(self.window, text="Checking...", font=("Arial", 12))
        self.status_label.pack(pady=20)

        self.install_btn = tk.Button(
            self.window,
            text="Install Missing",
            command=self._install_all
        )
        self.install_btn.pack(pady=10)

        self.continue_btn = tk.Button(
            self.window,
            text="Continue",
            command=self._complete_setup,
            state="disabled"
        )
        self.continue_btn.pack(pady=10)

    def _create_status_row(self, parent, name: str, description: str) -> dict:
        """Create a status row for a component."""
        row_frame = ctk.CTkFrame(parent, fg_color="transparent")
        row_frame.pack(fill="x", padx=15, pady=8)

        # Status indicator
        indicator = ctk.CTkLabel(
            row_frame,
            text="○",
            font=ctk.CTkFont(size=20),
            text_color="gray",
            width=30
        )
        indicator.pack(side="left")

        # Text
        text_frame = ctk.CTkFrame(row_frame, fg_color="transparent")
        text_frame.pack(side="left", fill="x", expand=True, padx=10)

        name_label = ctk.CTkLabel(
            text_frame,
            text=name,
            font=ctk.CTkFont(size=14, weight="bold"),
            anchor="w"
        )
        name_label.pack(anchor="w")

        desc_label = ctk.CTkLabel(
            text_frame,
            text=description,
            font=ctk.CTkFont(size=11),
            text_color="gray",
            anchor="w"
        )
        desc_label.pack(anchor="w")

        # Action button (hidden by default)
        action_btn = ctk.CTkButton(
            row_frame,
            text="Install",
            width=80,
            height=28,
            fg_color="gray40"
        )
        # Don't pack yet - will be shown when needed

        return {
            "frame": row_frame,
            "indicator": indicator,
            "name": name_label,
            "desc": desc_label,
            "action": action_btn,
            "status": None
        }

    def _update_status_row(self, key: str, installed: bool, status_text: str = ""):
        """Update a status row's visual state."""
        if key not in self.status_rows:
            return

        row = self.status_rows[key]

        if installed:
            row["indicator"].configure(text="✓", text_color="#28a745")
            row["desc"].configure(text=status_text or "Installed")
            row["action"].pack_forget()
        else:
            row["indicator"].configure(text="○", text_color="#dc3545")
            row["desc"].configure(text=status_text or "Not installed")

        row["status"] = installed

    def _check_status(self):
        """Check status of all components."""
        def progress(msg):
            self.window.after(0, lambda: self.progress_label.configure(text=msg))

        def check():
            self.window.after(0, lambda: self.progress_bar.set(0.1))
            status = self.wizard.check_all(on_progress=progress)

            self.window.after(0, lambda: self._update_ui_status(status))

        self.progress_label.configure(text="Checking system...")
        self.progress_bar.set(0)

        thread = threading.Thread(target=check, daemon=True)
        thread.start()

    def _update_ui_status(self, status: SetupStatus):
        """Update UI based on status check results."""
        self._update_status_row("obs", status.obs_installed,
            "Found" if status.obs_installed else "Not found - Please install OBS Studio")

        self._update_status_row("websocket", status.obs_websocket_enabled,
            "Enabled" if status.obs_websocket_enabled else "Not enabled - Click to configure")

        self._update_status_row("ffmpeg", status.ffmpeg_installed,
            "Found" if status.ffmpeg_installed else "Not installed - Click Install below")

        self._update_status_row("source_record", status.source_record_installed,
            "Found" if status.source_record_installed else "Not installed - Click Install below")

        self.progress_bar.set(1.0)

        # Update buttons visibility
        if status.all_ready:
            self.progress_label.configure(text="All components ready!")
            self.install_all_btn.pack_forget()
            self.websocket_btn.pack_forget()
            self.continue_btn.pack(fill="x", pady=10)
            self.info_label.configure(text="Setup complete! Click Continue to start using Tutorial Recorder.")
        else:
            self.continue_btn.pack_forget()

            missing = []
            if not status.obs_installed:
                missing.append("OBS Studio")
            if not status.obs_websocket_enabled:
                missing.append("WebSocket")
            if not status.ffmpeg_installed:
                missing.append("ffmpeg")
            if not status.source_record_installed:
                missing.append("Source Record")

            self.progress_label.configure(text=f"Missing: {', '.join(missing)}")

            # Show/hide appropriate buttons
            if not status.ffmpeg_installed or not status.source_record_installed:
                self.install_all_btn.pack(fill="x", pady=5)
            else:
                self.install_all_btn.pack_forget()

            if not status.obs_websocket_enabled and status.obs_installed:
                self.websocket_btn.pack(fill="x", pady=5)
            else:
                self.websocket_btn.pack_forget()

            if not status.obs_installed:
                self.info_label.configure(
                    text="Please download and install OBS Studio from https://obsproject.com"
                )
            elif not status.obs_websocket_enabled:
                self.info_label.configure(
                    text="Open OBS and go to Tools → WebSocket Server Settings → Enable WebSocket Server"
                )
            else:
                self.info_label.configure(text="Click 'Install Missing Components' to automatically install ffmpeg and the Source Record plugin.")

    def _install_all(self):
        """Install all missing components."""
        if self._installing:
            return

        self._installing = True
        self.install_all_btn.configure(state="disabled", text="Installing...")
        self.refresh_btn.configure(state="disabled")

        def do_install():
            try:
                status = self.wizard.status

                # Install ffmpeg if needed
                if not status.ffmpeg_installed:
                    def ffmpeg_progress(msg, pct):
                        self.window.after(0, lambda: self.progress_label.configure(text=f"ffmpeg: {msg}"))
                        if pct >= 0:
                            self.window.after(0, lambda: self.progress_bar.set(pct / 100 * 0.5))

                    success, message = self.wizard.install_ffmpeg(on_progress=ffmpeg_progress)
                    if success:
                        self.window.after(0, lambda: self._update_status_row("ffmpeg", True, "Installed"))
                    else:
                        self.window.after(0, lambda: self._update_status_row("ffmpeg", False, message))

                # Install Source Record if needed
                if not status.source_record_installed:
                    def sr_progress(msg, pct):
                        self.window.after(0, lambda: self.progress_label.configure(text=f"Source Record: {msg}"))
                        if pct >= 0:
                            self.window.after(0, lambda: self.progress_bar.set(0.5 + pct / 100 * 0.5))

                    success, message = self.wizard.install_source_record(on_progress=sr_progress)
                    if success:
                        self.window.after(0, lambda: self._update_status_row("source_record", True, "Installed - Restart OBS"))
                    else:
                        self.window.after(0, lambda: self._update_status_row("source_record", False, message))

                # Re-check status
                self.window.after(500, self._check_status)

            finally:
                self._installing = False
                self.window.after(0, lambda: self.install_all_btn.configure(state="normal", text="Install Missing Components"))
                self.window.after(0, lambda: self.refresh_btn.configure(state="normal"))

        thread = threading.Thread(target=do_install, daemon=True)
        thread.start()

    def _open_obs_for_websocket(self):
        """Open OBS for WebSocket configuration."""
        if self.wizard.open_obs_for_websocket_setup():
            self.info_label.configure(
                text="OBS is opening. Go to Tools → WebSocket Server Settings → Enable WebSocket Server, then click Refresh Status."
            )
        else:
            self.info_label.configure(
                text="Could not open OBS. Please open it manually and enable WebSocket."
            )

    def _complete_setup(self):
        """Complete setup and continue to app."""
        self.wizard.mark_setup_complete()
        self.window.destroy()
        if self.on_complete:
            self.on_complete()

    def show(self):
        """Show the setup dialog."""
        self.window.mainloop()

    def run(self):
        """Run the setup dialog (alias for show)."""
        self.show()


def run_setup_if_needed(on_complete: Optional[Callable[[], None]] = None) -> bool:
    """
    Run setup wizard if this is first run or components are missing.
    Returns True if setup was needed and completed, False if skipped.
    """
    wizard = get_setup_wizard()

    # Always check status
    status = wizard.check_all()

    # Show setup if first run OR if critical components are missing
    if wizard.is_first_run() or not status.can_record:
        log_info("Running setup wizard...")
        dialog = SetupDialog(on_complete=on_complete)
        dialog.show()
        return True

    # If setup was done before but some components are missing, show dialog
    if not status.all_ready:
        log_info("Some components missing, showing setup...")
        dialog = SetupDialog(on_complete=on_complete)
        dialog.show()
        return True

    return False
