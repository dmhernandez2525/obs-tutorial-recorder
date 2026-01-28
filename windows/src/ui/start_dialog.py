"""
Start Recording Dialog.
Allows user to select profile and enter project name.
"""

import tkinter as tk
from tkinter import ttk
from typing import Callable, List, Optional, Tuple

try:
    import customtkinter as ctk
    CTK_AVAILABLE = True
except ImportError:
    CTK_AVAILABLE = False
    ctk = None

from ..utils.logger import log_info


class StartRecordingDialog:
    """
    Dialog for starting a new recording.
    Shows profile selection and project name input.
    """

    def __init__(
        self,
        profiles: List[str],
        existing_projects: List[dict],
        on_start: Callable[[str, str], None],
        parent: Optional[tk.Tk] = None
    ):
        self.profiles = profiles
        self.existing_projects = existing_projects
        self.on_start = on_start
        self.result: Optional[Tuple[str, str]] = None

        # Create window
        if CTK_AVAILABLE:
            self._create_ctk_window(parent)
        else:
            self._create_tk_window(parent)

    def _create_ctk_window(self, parent: Optional[tk.Tk]):
        """Create CustomTkinter dialog."""
        if parent:
            self.window = ctk.CTkToplevel(parent)
        else:
            self.window = ctk.CTk()

        self.window.title("Start Recording")
        self.window.geometry("450x350")
        self.window.resizable(False, False)

        # Center on screen
        self.window.update_idletasks()
        x = (self.window.winfo_screenwidth() - 450) // 2
        y = (self.window.winfo_screenheight() - 350) // 2
        self.window.geometry(f"+{x}+{y}")

        # Main frame
        main_frame = ctk.CTkFrame(self.window)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Title
        title = ctk.CTkLabel(
            main_frame,
            text="Start New Recording",
            font=ctk.CTkFont(size=20, weight="bold")
        )
        title.pack(pady=(0, 20))

        # Profile selection
        profile_label = ctk.CTkLabel(main_frame, text="Recording Profile:")
        profile_label.pack(anchor="w")

        self.profile_var = ctk.StringVar(value=self.profiles[0] if self.profiles else "")
        self.profile_dropdown = ctk.CTkComboBox(
            main_frame,
            values=self.profiles,
            variable=self.profile_var,
            width=400
        )
        self.profile_dropdown.pack(pady=(5, 15))

        # Project name
        name_label = ctk.CTkLabel(main_frame, text="Project Name:")
        name_label.pack(anchor="w")

        self.name_var = ctk.StringVar()
        self.name_entry = ctk.CTkEntry(
            main_frame,
            textvariable=self.name_var,
            placeholder_text="Enter project name...",
            width=400
        )
        self.name_entry.pack(pady=(5, 15))

        # Continue existing project
        if self.existing_projects:
            continue_label = ctk.CTkLabel(main_frame, text="Or continue existing project:")
            continue_label.pack(anchor="w", pady=(10, 0))

            project_names = [p['name'] for p in self.existing_projects]
            self.existing_var = ctk.StringVar(value="")
            self.existing_dropdown = ctk.CTkComboBox(
                main_frame,
                values=[""] + project_names,
                variable=self.existing_var,
                width=400,
                command=self._on_existing_selected
            )
            self.existing_dropdown.pack(pady=(5, 15))

        # Buttons
        button_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        button_frame.pack(fill="x", pady=(20, 0))

        cancel_btn = ctk.CTkButton(
            button_frame,
            text="Cancel",
            command=self._on_cancel,
            fg_color="gray",
            width=120
        )
        cancel_btn.pack(side="left")

        start_btn = ctk.CTkButton(
            button_frame,
            text="Start Recording",
            command=self._on_start,
            width=150
        )
        start_btn.pack(side="right")

        # Bind Enter key
        self.window.bind('<Return>', lambda e: self._on_start())
        self.window.bind('<Escape>', lambda e: self._on_cancel())

        # Focus on name entry
        self.name_entry.focus()

    def _create_tk_window(self, parent: Optional[tk.Tk]):
        """Create standard Tkinter dialog (fallback)."""
        if parent:
            self.window = tk.Toplevel(parent)
        else:
            self.window = tk.Tk()

        self.window.title("Start Recording")
        self.window.geometry("400x300")

        # Profile selection
        tk.Label(self.window, text="Recording Profile:").pack(pady=(20, 5))
        self.profile_var = tk.StringVar(value=self.profiles[0] if self.profiles else "")
        profile_dropdown = ttk.Combobox(
            self.window,
            textvariable=self.profile_var,
            values=self.profiles,
            state="readonly",
            width=40
        )
        profile_dropdown.pack()

        # Project name
        tk.Label(self.window, text="Project Name:").pack(pady=(20, 5))
        self.name_var = tk.StringVar()
        name_entry = ttk.Entry(self.window, textvariable=self.name_var, width=43)
        name_entry.pack()

        # Buttons
        button_frame = tk.Frame(self.window)
        button_frame.pack(pady=30)

        ttk.Button(button_frame, text="Cancel", command=self._on_cancel).pack(side="left", padx=10)
        ttk.Button(button_frame, text="Start Recording", command=self._on_start).pack(side="left", padx=10)

        name_entry.focus()

    def _on_existing_selected(self, selection: str):
        """Handle existing project selection."""
        if selection:
            self.name_var.set(selection)

    def _on_start(self):
        """Handle start button click."""
        project_name = self.name_var.get().strip()
        profile_name = self.profile_var.get()

        if not project_name:
            # Show error
            if CTK_AVAILABLE:
                error_label = ctk.CTkLabel(
                    self.window,
                    text="Please enter a project name",
                    text_color="red"
                )
                error_label.pack()
                self.window.after(2000, error_label.destroy)
            return

        if not profile_name:
            return

        self.result = (project_name, profile_name)
        log_info(f"Starting recording: {project_name} with profile {profile_name}")

        self.window.destroy()

        # Call the callback
        if self.on_start:
            self.on_start(project_name, profile_name)

    def _on_cancel(self):
        """Handle cancel button click."""
        self.result = None
        self.window.destroy()

    def show(self):
        """Show the dialog and wait for result."""
        self.window.grab_set()
        self.window.wait_window()
        return self.result

    def run(self):
        """Run the dialog (for standalone use)."""
        self.window.mainloop()


def show_start_dialog(
    profiles: List[str],
    existing_projects: List[dict],
    on_start: Callable[[str, str], None]
) -> Optional[Tuple[str, str]]:
    """
    Show the start recording dialog.
    Returns (project_name, profile_name) or None if cancelled.
    """
    dialog = StartRecordingDialog(profiles, existing_projects, on_start)
    return dialog.show()
