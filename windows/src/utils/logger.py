"""
Logging utilities for OBS Tutorial Recorder.
Supports both session-specific and global application logging.
"""

import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

from .paths import get_app_log_path, ensure_dir


class TutorialLogger:
    """Logger that writes to both session log and global app log."""

    def __init__(self, name: str = "TutorialRecorder"):
        self.name = name
        self.session_path: Optional[Path] = None
        self._setup_app_logger()

    def _setup_app_logger(self):
        """Set up the global application logger."""
        self.app_logger = logging.getLogger(self.name)
        self.app_logger.setLevel(logging.DEBUG)

        # Ensure log directory exists
        log_path = get_app_log_path()
        ensure_dir(log_path.parent)

        # File handler for app log
        file_handler = logging.FileHandler(log_path, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%dT%H:%M:%S'
        ))

        # Console handler - show DEBUG level for detailed troubleshooting
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG)
        console_handler.setFormatter(logging.Formatter(
            '[%(levelname)s] %(message)s'
        ))

        # Clear existing handlers and add new ones
        self.app_logger.handlers.clear()
        self.app_logger.addHandler(file_handler)
        self.app_logger.addHandler(console_handler)

    def set_session(self, project_path: Path):
        """Set the session log path for project-specific logging."""
        self.session_path = project_path / "session.log"
        ensure_dir(project_path)

    def clear_session(self):
        """Clear the session log path."""
        self.session_path = None

    def _log_to_session(self, level: str, message: str):
        """Write to session log file if active."""
        if self.session_path:
            timestamp = datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')
            try:
                with open(self.session_path, 'a', encoding='utf-8') as f:
                    f.write(f"[{timestamp}] [{level}] {message}\n")
            except Exception:
                pass  # Don't fail on logging errors

    def info(self, message: str):
        """Log info message."""
        self.app_logger.info(message)
        self._log_to_session("INFO", message)

    def progress(self, message: str):
        """Log progress message for user feedback."""
        print(f"[PROGRESS] {message}")  # Direct print for immediate feedback
        self.app_logger.info(f"PROGRESS: {message}")
        self._log_to_session("PROGRESS", message)

    def success(self, message: str):
        """Log success message (treated as INFO level)."""
        self.app_logger.info(f"SUCCESS: {message}")
        self._log_to_session("SUCCESS", message)

    def warning(self, message: str):
        """Log warning message."""
        self.app_logger.warning(message)
        self._log_to_session("WARNING", message)

    def error(self, message: str):
        """Log error message."""
        self.app_logger.error(message)
        self._log_to_session("ERROR", message)

    def debug(self, message: str):
        """Log debug message."""
        self.app_logger.debug(message)
        self._log_to_session("DEBUG", message)


# Global logger instance
_logger: Optional[TutorialLogger] = None


def get_logger() -> TutorialLogger:
    """Get the global logger instance."""
    global _logger
    if _logger is None:
        _logger = TutorialLogger()
    return _logger


def log_info(message: str):
    """Convenience function for info logging."""
    get_logger().info(message)


def log_progress(message: str):
    """Convenience function for progress logging."""
    get_logger().progress(message)


def log_success(message: str):
    """Convenience function for success logging."""
    get_logger().success(message)


def log_warning(message: str):
    """Convenience function for warning logging."""
    get_logger().warning(message)


def log_error(message: str):
    """Convenience function for error logging."""
    get_logger().error(message)


def log_debug(message: str):
    """Convenience function for debug logging."""
    get_logger().debug(message)


def set_session_log(project_path: Path):
    """Set the session log path."""
    get_logger().set_session(project_path)


def clear_session_log():
    """Clear the session log path."""
    get_logger().clear_session()
