"""
Progress Dialog.
Shows progress during recording start/stop operations.
"""

import tkinter as tk
from typing import Optional

try:
    import customtkinter as ctk
    CTK_AVAILABLE = True
except ImportError:
    CTK_AVAILABLE = False
    ctk = None


class ProgressDialog:
    """
    Always-on-top progress indicator.
    Shows current operation status.
    """

    def __init__(self, title: str = "Please Wait", parent: Optional[tk.Tk] = None):
        self.title = title
        self._message = ""

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

        self.window.title(self.title)
        self.window.geometry("350x150")
        self.window.resizable(False, False)

        # Always on top
        self.window.attributes('-topmost', True)

        # Center on screen
        self.window.update_idletasks()
        x = (self.window.winfo_screenwidth() - 350) // 2
        y = (self.window.winfo_screenheight() - 150) // 2
        self.window.geometry(f"+{x}+{y}")

        # Main frame
        main_frame = ctk.CTkFrame(self.window)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Progress bar
        self.progress = ctk.CTkProgressBar(main_frame, mode="indeterminate", width=280)
        self.progress.pack(pady=(20, 15))
        self.progress.start()

        # Message label
        self.message_label = ctk.CTkLabel(
            main_frame,
            text="Initializing...",
            font=ctk.CTkFont(size=14)
        )
        self.message_label.pack()

        # Prevent closing
        self.window.protocol("WM_DELETE_WINDOW", lambda: None)

    def _create_tk_window(self, parent: Optional[tk.Tk]):
        """Create standard Tkinter window (fallback)."""
        if parent:
            self.window = tk.Toplevel(parent)
        else:
            self.window = tk.Tk()

        self.window.title(self.title)
        self.window.geometry("300x120")
        self.window.attributes('-topmost', True)

        self.message_label = tk.Label(self.window, text="Initializing...", font=("Arial", 12))
        self.message_label.pack(pady=30)

        from tkinter import ttk
        self.progress = ttk.Progressbar(self.window, mode="indeterminate", length=250)
        self.progress.pack(pady=10)
        self.progress.start()

        self.window.protocol("WM_DELETE_WINDOW", lambda: None)

    def set_message(self, message: str):
        """Update the progress message."""
        self._message = message
        if CTK_AVAILABLE:
            self.message_label.configure(text=message)
        else:
            self.message_label.config(text=message)
        self.window.update()

    def close(self):
        """Close the progress dialog."""
        if CTK_AVAILABLE:
            self.progress.stop()
        else:
            self.progress.stop()
        self.window.destroy()

    def show(self):
        """Show the dialog (non-blocking)."""
        self.window.update()

    def run(self):
        """Run the dialog (blocking)."""
        self.window.mainloop()


def show_progress(title: str = "Please Wait") -> ProgressDialog:
    """
    Create and show a progress dialog.
    Returns the dialog so the caller can update it.
    """
    dialog = ProgressDialog(title)
    dialog.show()
    return dialog
