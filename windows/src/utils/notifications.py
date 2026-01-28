"""
Windows notifications utilities.
Uses plyer for cross-platform notifications.
"""

from typing import Optional

from .logger import log_debug, log_warning


def show_notification(
    title: str,
    message: str,
    app_name: str = "Tutorial Recorder",
    timeout: int = 5
):
    """
    Show a Windows toast notification.

    Args:
        title: Notification title
        message: Notification body text
        app_name: Application name
        timeout: Seconds to show notification
    """
    try:
        from plyer import notification
        notification.notify(
            title=title,
            message=message,
            app_name=app_name,
            timeout=timeout
        )
        log_debug(f"Notification: {title}")
    except ImportError:
        log_warning("plyer not installed, skipping notification")
    except Exception as e:
        log_warning(f"Notification failed: {e}")


def notify_recording_started(project_name: str):
    """Notify that recording has started."""
    show_notification(
        title="Recording Started",
        message=f"Recording: {project_name}"
    )


def notify_recording_stopped(project_name: str):
    """Notify that recording has stopped."""
    show_notification(
        title="Recording Stopped",
        message=f"Project saved: {project_name}"
    )


def notify_sync_complete(files_count: int = 0):
    """Notify that sync is complete."""
    if files_count > 0:
        message = f"Synced {files_count} file(s) to cloud"
    else:
        message = "All files are up to date"

    show_notification(
        title="Sync Complete",
        message=message
    )


def notify_transcription_complete(output_file: Optional[str] = None):
    """Notify that transcription is complete."""
    if output_file:
        message = f"Saved to: {output_file}"
    else:
        message = "Transcription complete"

    show_notification(
        title="Transcription Complete",
        message=message
    )


def notify_error(error_message: str):
    """Notify of an error."""
    show_notification(
        title="Error",
        message=error_message,
        timeout=10
    )
