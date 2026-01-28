"""Test if the app can launch at all."""
import tkinter as tk
from tkinter import messagebox
import sys
from pathlib import Path

# Show a message box to confirm the app launched
root = tk.Tk()
root.withdraw()

try:
    # Add src to path
    src_path = Path(__file__).parent / "src"
    sys.path.insert(0, str(src_path))

    # Test imports
    from src.app import get_app
    from src.ui.system_tray import SystemTray, PYSTRAY_AVAILABLE

    if not PYSTRAY_AVAILABLE:
        messagebox.showerror("Error", "pystray is not available!")
        sys.exit(1)

    # Show success and instructions
    messagebox.showinfo(
        "Tutorial Recorder",
        "App is starting!\n\nLook for the tray icon in the bottom-right corner.\n\nClick the ^ arrow if you don't see it."
    )

    # Now run the actual app
    from run import main
    main()

except Exception as e:
    messagebox.showerror("Error", f"Failed to start:\n\n{e}")
    raise
