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


def run_main_app():
    """Run the main application after setup is complete."""
    print("[DEBUG] run_main_app() starting")

    from src.app import get_app
    from src.ui.main_window import MainWindow
    from src.utils.logger import log_info

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


def main():
    """Main entry point."""
    print("[DEBUG] main() starting")

    try:
        print("[DEBUG] Importing modules...")
        from src.utils.logger import log_info, log_error
        print("[DEBUG] Logger imported")

        from src.ui.setup_dialog import run_setup_if_needed
        from src.core.setup_wizard import get_setup_wizard
        print("[DEBUG] Setup modules imported")

        log_info("OBS Tutorial Recorder starting...")

        # Check if setup is needed
        print("[DEBUG] Checking if setup is needed...")
        wizard = get_setup_wizard()

        if wizard.is_first_run():
            print("[DEBUG] First run detected, showing setup wizard...")
            log_info("First run - showing setup wizard")

            # Run setup wizard, then start main app when complete
            from src.ui.setup_dialog import SetupDialog
            dialog = SetupDialog(on_complete=run_main_app)
            dialog.show()
        else:
            # Quick check for missing critical components
            status = wizard.check_all()
            if not status.can_record:
                print("[DEBUG] Critical components missing, showing setup wizard...")
                log_info("Critical components missing - showing setup wizard")
                from src.ui.setup_dialog import SetupDialog
                dialog = SetupDialog(on_complete=run_main_app)
                dialog.show()
            else:
                # All good, run main app directly
                print("[DEBUG] Setup already complete, starting main app...")
                run_main_app()

        print("[DEBUG] Application ended")

    except Exception as e:
        print(f"[ERROR] Application error: {e}")
        traceback.print_exc()
        input("Press Enter to exit...")
        raise
    finally:
        print("[DEBUG] Shutting down...")
        try:
            from src.app import shutdown_app
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
