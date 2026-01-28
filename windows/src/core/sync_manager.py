"""
Cloud Sync Manager for Windows.
Uses rclone to sync recordings to Google Drive.
"""

import os
import subprocess
import threading
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Callable, List, Optional

from ..utils.config import SyncConfig, get_config_manager
from ..utils.paths import get_rclone_config_path, get_recordings_base
from ..utils.logger import log_info, log_error, log_warning, log_success


class SyncStatus(Enum):
    """Sync operation status."""
    NOT_INSTALLED = "not_installed"
    NOT_CONFIGURED = "not_configured"
    READY = "ready"
    SYNCING = "syncing"
    ERROR = "error"


@dataclass
class SyncResult:
    """Result of a sync operation."""
    success: bool
    files_transferred: int = 0
    bytes_transferred: int = 0
    errors: int = 0
    message: str = ""


class SyncManager:
    """
    Manages cloud sync operations via rclone.
    """

    def __init__(self):
        self._config = get_config_manager().get_sync_config()
        self._status = SyncStatus.NOT_INSTALLED
        self._is_syncing = False
        self._last_sync: Optional[datetime] = None
        self._callbacks: List[Callable[[SyncStatus, str], None]] = []

        self._check_rclone()

    def _check_rclone(self) -> bool:
        """Check if rclone is installed and configured."""
        # Check if rclone is in PATH
        try:
            result = subprocess.run(
                ['rclone', 'version'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode != 0:
                self._status = SyncStatus.NOT_INSTALLED
                return False
        except FileNotFoundError:
            self._status = SyncStatus.NOT_INSTALLED
            return False
        except Exception as e:
            log_warning(f"rclone check failed: {e}")
            self._status = SyncStatus.NOT_INSTALLED
            return False

        # Check if configured
        config_path = get_rclone_config_path()
        if not config_path.exists():
            self._status = SyncStatus.NOT_CONFIGURED
            return False

        # Check for our remote
        try:
            result = subprocess.run(
                ['rclone', 'listremotes'],
                capture_output=True,
                text=True,
                timeout=10
            )
            remotes = result.stdout.strip().split('\n')
            remote_name = self._config.rclone_remote + ':'

            if remote_name not in remotes:
                self._status = SyncStatus.NOT_CONFIGURED
                return False

        except Exception as e:
            log_warning(f"rclone config check failed: {e}")
            self._status = SyncStatus.NOT_CONFIGURED
            return False

        self._status = SyncStatus.READY
        return True

    @property
    def status(self) -> SyncStatus:
        return self._status

    @property
    def is_syncing(self) -> bool:
        return self._is_syncing

    @property
    def last_sync(self) -> Optional[datetime]:
        return self._last_sync

    def add_callback(self, callback: Callable[[SyncStatus, str], None]):
        """Add a callback for sync status updates."""
        self._callbacks.append(callback)

    def _notify(self, status: SyncStatus, message: str):
        """Notify callbacks of status change."""
        self._status = status
        for callback in self._callbacks:
            try:
                callback(status, message)
            except Exception:
                pass

    def get_installation_instructions(self) -> str:
        """Get instructions for installing rclone."""
        return """
To install rclone on Windows:

1. Using winget (recommended):
   winget install Rclone.Rclone

2. Using Chocolatey:
   choco install rclone

3. Manual download:
   https://rclone.org/downloads/

After installation, configure Google Drive:
   rclone config
   - Choose 'n' for new remote
   - Name it 'tutorial-recordings'
   - Choose 'drive' for Google Drive
   - Follow the authentication prompts
"""

    def configure_remote(self) -> bool:
        """
        Launch rclone config to set up Google Drive.
        Returns True if configuration was started.
        """
        try:
            # Open terminal with rclone config
            subprocess.Popen(
                ['cmd', '/k', 'rclone', 'config'],
                creationflags=subprocess.CREATE_NEW_CONSOLE
            )
            log_info("Launched rclone configuration")
            return True
        except Exception as e:
            log_error(f"Failed to launch rclone config: {e}")
            return False

    def sync(
        self,
        on_progress: Optional[Callable[[str], None]] = None,
        dry_run: bool = False
    ) -> SyncResult:
        """
        Sync recordings to cloud.
        Blocks until complete.
        """
        if self._is_syncing:
            return SyncResult(success=False, message="Sync already in progress")

        if self._status == SyncStatus.NOT_INSTALLED:
            return SyncResult(success=False, message="rclone not installed")

        if self._status == SyncStatus.NOT_CONFIGURED:
            return SyncResult(success=False, message="rclone not configured")

        self._is_syncing = True
        self._notify(SyncStatus.SYNCING, "Syncing...")

        try:
            local_path = self._config.local_path
            remote = f"{self._config.rclone_remote}:{self._config.remote_path}"

            cmd = ['rclone', 'sync', local_path, remote, '-v', '--stats', '1s']

            if dry_run:
                cmd.append('--dry-run')

            # Add exclude patterns
            for pattern in self._config.exclude_patterns:
                cmd.extend(['--exclude', pattern])

            if self._config.sync_exports_only:
                cmd.extend(['--include', 'exports/**', '--exclude', '*'])

            log_info(f"Running: {' '.join(cmd)}")

            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            files_transferred = 0
            bytes_transferred = 0
            errors = 0

            for line in process.stdout:
                line = line.strip()
                if on_progress:
                    on_progress(line)

                # Parse progress
                if 'Transferred:' in line:
                    # Parse transfer stats
                    pass
                elif 'Errors:' in line:
                    try:
                        errors = int(line.split(':')[1].strip())
                    except Exception:
                        pass

            process.wait()

            success = process.returncode == 0
            self._last_sync = datetime.now()

            if success:
                log_success("Sync completed successfully")
                self._notify(SyncStatus.READY, "Sync complete")
            else:
                log_error(f"Sync failed with code {process.returncode}")
                self._notify(SyncStatus.ERROR, "Sync failed")

            return SyncResult(
                success=success,
                files_transferred=files_transferred,
                bytes_transferred=bytes_transferred,
                errors=errors,
                message="Sync complete" if success else "Sync failed"
            )

        except Exception as e:
            log_error(f"Sync error: {e}")
            self._notify(SyncStatus.ERROR, str(e))
            return SyncResult(success=False, message=str(e))

        finally:
            self._is_syncing = False

    def sync_async(
        self,
        on_progress: Optional[Callable[[str], None]] = None,
        on_complete: Optional[Callable[[SyncResult], None]] = None
    ):
        """
        Sync recordings to cloud asynchronously.
        """
        def run_sync():
            result = self.sync(on_progress)
            if on_complete:
                on_complete(result)

        thread = threading.Thread(target=run_sync, daemon=True)
        thread.start()

    def test_connection(self) -> bool:
        """Test the rclone connection to the remote."""
        if self._status in (SyncStatus.NOT_INSTALLED, SyncStatus.NOT_CONFIGURED):
            return False

        try:
            remote = f"{self._config.rclone_remote}:"
            result = subprocess.run(
                ['rclone', 'lsd', remote, '--max-depth', '1'],
                capture_output=True,
                timeout=30
            )
            return result.returncode == 0
        except Exception as e:
            log_error(f"Connection test failed: {e}")
            return False

    def get_pending_files(self) -> List[str]:
        """Get list of files that need to be synced."""
        if self._status in (SyncStatus.NOT_INSTALLED, SyncStatus.NOT_CONFIGURED):
            return []

        try:
            local_path = self._config.local_path
            remote = f"{self._config.rclone_remote}:{self._config.remote_path}"

            result = subprocess.run(
                ['rclone', 'check', local_path, remote, '--one-way', '--combined', '-'],
                capture_output=True,
                text=True,
                timeout=60
            )

            pending = []
            for line in result.stdout.split('\n'):
                if line.startswith('+'):  # Missing on remote
                    pending.append(line[2:])

            return pending

        except Exception as e:
            log_warning(f"Failed to get pending files: {e}")
            return []


# Global sync manager instance
_sync_manager: Optional[SyncManager] = None


def get_sync_manager() -> SyncManager:
    """Get the global sync manager instance."""
    global _sync_manager
    if _sync_manager is None:
        _sync_manager = SyncManager()
    return _sync_manager
