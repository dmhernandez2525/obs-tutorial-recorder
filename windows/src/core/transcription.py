"""
Transcription Manager for Windows.
Uses faster-whisper for local AI transcription.
"""

import subprocess
import threading
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Callable, Optional

from ..utils.config import TranscriptionConfig, get_config_manager
from ..utils.paths import get_whisper_models_dir, ensure_dir
from ..utils.logger import log_info, log_error, log_warning, log_success


class TranscriptionStatus(Enum):
    """Transcription operation status."""
    NOT_AVAILABLE = "not_available"
    READY = "ready"
    TRANSCRIBING = "transcribing"
    COMPLETE = "complete"
    ERROR = "error"


@dataclass
class TranscriptionResult:
    """Result of a transcription operation."""
    success: bool
    text: str = ""
    output_path: Optional[Path] = None
    message: str = ""


# Model sizes and their approximate download sizes
WHISPER_MODELS = {
    "tiny": {"size": "75MB", "quality": "Fast, lower accuracy"},
    "base": {"size": "150MB", "quality": "Balanced speed/accuracy"},
    "small": {"size": "500MB", "quality": "Good accuracy (recommended)"},
    "medium": {"size": "1.5GB", "quality": "High accuracy, slower"},
}


class TranscriptionManager:
    """
    Manages audio transcription using Whisper.
    """

    def __init__(self):
        self._config = get_config_manager().get_transcription_config()
        self._status = TranscriptionStatus.NOT_AVAILABLE
        self._is_transcribing = False
        self._whisper_available = False

        self._check_whisper()

    def _check_whisper(self) -> bool:
        """Check if Whisper is available."""
        try:
            import faster_whisper
            self._whisper_available = True
            self._status = TranscriptionStatus.READY
            log_info("faster-whisper is available")
            return True
        except ImportError:
            log_warning("faster-whisper not installed. Run: pip install faster-whisper")
            self._status = TranscriptionStatus.NOT_AVAILABLE
            return False

    @property
    def status(self) -> TranscriptionStatus:
        return self._status

    @property
    def is_transcribing(self) -> bool:
        return self._is_transcribing

    @property
    def is_available(self) -> bool:
        return self._whisper_available

    @property
    def config(self) -> TranscriptionConfig:
        return self._config

    def get_available_models(self) -> dict:
        """Get available Whisper models with info."""
        return WHISPER_MODELS.copy()

    def is_model_downloaded(self, model_name: str) -> bool:
        """Check if a model is downloaded."""
        # faster-whisper downloads models automatically
        # This checks the cache
        cache_dir = get_whisper_models_dir()
        model_dir = cache_dir / f"models--Systran--faster-whisper-{model_name}"
        return model_dir.exists()

    def extract_audio(
        self,
        video_path: Path,
        output_path: Optional[Path] = None
    ) -> Optional[Path]:
        """
        Extract audio from a video file using ffmpeg.
        Returns path to the audio file.
        """
        if output_path is None:
            output_path = video_path.with_suffix('.wav')

        try:
            # Check if ffmpeg is available
            subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            log_error("ffmpeg not found. Please install ffmpeg and add to PATH.")
            return None

        try:
            cmd = [
                'ffmpeg', '-y',
                '-i', str(video_path),
                '-vn',  # No video
                '-acodec', 'pcm_s16le',  # WAV format
                '-ar', '16000',  # 16kHz sample rate (Whisper optimal)
                '-ac', '1',  # Mono
                str(output_path)
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode == 0 and output_path.exists():
                log_info(f"Extracted audio: {output_path.name}")
                return output_path
            else:
                log_error(f"Audio extraction failed: {result.stderr}")
                return None

        except subprocess.TimeoutExpired:
            log_error("Audio extraction timed out")
            return None
        except Exception as e:
            log_error(f"Audio extraction error: {e}")
            return None

    def transcribe(
        self,
        audio_path: Path,
        output_path: Optional[Path] = None,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> TranscriptionResult:
        """
        Transcribe an audio file.
        Blocks until complete.
        """
        if not self._whisper_available:
            return TranscriptionResult(
                success=False,
                message="Whisper not available. Run: pip install faster-whisper"
            )

        if self._is_transcribing:
            return TranscriptionResult(
                success=False,
                message="Transcription already in progress"
            )

        self._is_transcribing = True
        self._status = TranscriptionStatus.TRANSCRIBING

        if on_progress:
            on_progress("Loading model...")

        try:
            from faster_whisper import WhisperModel

            # Set cache directory
            cache_dir = get_whisper_models_dir()
            ensure_dir(cache_dir)

            # Load model
            model_name = self._config.model
            log_info(f"Loading Whisper model: {model_name}")

            model = WhisperModel(
                model_name,
                device="cpu",  # Use CPU for compatibility
                compute_type="int8",  # Faster on CPU
                download_root=str(cache_dir)
            )

            if on_progress:
                on_progress("Transcribing...")

            # Transcribe
            segments, info = model.transcribe(
                str(audio_path),
                language=self._config.language,
                beam_size=5,
                vad_filter=True
            )

            # Collect text
            full_text = []
            for segment in segments:
                text = segment.text.strip()
                if text:
                    full_text.append(text)
                    if on_progress:
                        on_progress(f"Transcribing: {len(full_text)} segments...")

            transcript = " ".join(full_text)

            # Save to file
            if output_path is None:
                output_path = audio_path.with_name("transcript.txt")

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(transcript)

            log_success(f"Transcription complete: {output_path.name}")
            self._status = TranscriptionStatus.COMPLETE

            return TranscriptionResult(
                success=True,
                text=transcript,
                output_path=output_path,
                message=f"Transcribed {len(full_text)} segments"
            )

        except Exception as e:
            log_error(f"Transcription error: {e}")
            self._status = TranscriptionStatus.ERROR
            return TranscriptionResult(
                success=False,
                message=str(e)
            )

        finally:
            self._is_transcribing = False

    def transcribe_async(
        self,
        audio_path: Path,
        output_path: Optional[Path] = None,
        on_progress: Optional[Callable[[str], None]] = None,
        on_complete: Optional[Callable[[TranscriptionResult], None]] = None
    ):
        """
        Transcribe an audio file asynchronously.
        """
        def run_transcription():
            result = self.transcribe(audio_path, output_path, on_progress)
            if on_complete:
                on_complete(result)

        thread = threading.Thread(target=run_transcription, daemon=True)
        thread.start()

    def transcribe_video(
        self,
        video_path: Path,
        on_progress: Optional[Callable[[str], None]] = None
    ) -> TranscriptionResult:
        """
        Transcribe audio from a video file.
        Extracts audio first, then transcribes.
        """
        if on_progress:
            on_progress("Extracting audio...")

        # Extract audio
        audio_path = self.extract_audio(video_path)
        if audio_path is None:
            return TranscriptionResult(
                success=False,
                message="Failed to extract audio"
            )

        # Transcribe
        result = self.transcribe(
            audio_path,
            video_path.with_name("transcript.txt"),
            on_progress
        )

        # Clean up temporary audio file
        try:
            audio_path.unlink()
        except Exception:
            pass

        return result


# Global transcription manager instance
_transcription_manager: Optional[TranscriptionManager] = None


def get_transcription_manager() -> TranscriptionManager:
    """Get the global transcription manager instance."""
    global _transcription_manager
    if _transcription_manager is None:
        _transcription_manager = TranscriptionManager()
    return _transcription_manager
