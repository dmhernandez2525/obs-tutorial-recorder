#!/usr/bin/env python3
"""
OBS Tutorial Recorder - Windows
Entry point for the application.
"""

import sys
import traceback
from pathlib import Path

print("[DEBUG] Starting Tutorial Recorder...")
print(f"[DEBUG] Python version: {sys.version}")
print(f"[DEBUG] Script path: {__file__}")

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))
print(f"[DEBUG] Added to path: {src_path}")


def main():
    """Main entry point."""
    print("[DEBUG] main() starting")

    try:
        print("[DEBUG] Importing app module...")
        from src.app import get_app, shutdown_app
        print("[DEBUG] App module imported")

        print("[DEBUG] Importing MainWindow...")
        from src.ui.main_window import MainWindow
        print("[DEBUG] MainWindow imported")

        print("[DEBUG] Importing logger...")
        from src.utils.logger import log_info, log_error
        print("[DEBUG] Logger imported")

        # Initialize app
        print("[DEBUG] Initializing app...")
        app = get_app()
        print("[DEBUG] App initialized")

        log_info("OBS Tutorial Recorder starting...")

        # Create and run main window
        print("[DEBUG] Creating MainWindow...")
        window = MainWindow(app)
        print("[DEBUG] MainWindow created, starting main loop...")

        window.run()

        print("[DEBUG] Main loop ended")

    except Exception as e:
        print(f"[ERROR] Application error: {e}")
        traceback.print_exc()
        input("Press Enter to exit...")
        raise
    finally:
        print("[DEBUG] Shutting down...")
        try:
            shutdown_app()
        except Exception as e:
            print(f"[ERROR] Shutdown error: {e}")
        print("[DEBUG] Shutdown complete")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[FATAL] {e}")
        traceback.print_exc()
        input("Press Enter to exit...")
