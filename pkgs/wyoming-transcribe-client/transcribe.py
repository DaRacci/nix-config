#!/usr/bin/env python3
"""Wyoming STT client for Hermes agent.

Receives a WAV file (Hermes pre-converts non-WAV via ffmpeg in
_prepare_local_audio), parses audio metadata from WAV header,
sends to Wyoming faster-whisper server, writes transcript .txt.

Designed for HERMES_LOCAL_STT_COMMAND variable.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import tempfile
import unittest
import wave
from pathlib import Path

from wyoming.asr import Transcribe, Transcript
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.client import AsyncTcpClient


def write_transcript(output_dir: Path, text: str) -> Path:
    """Create output directory if needed and write transcript text."""
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "output.txt"
    output_path.write_text(text.strip(), encoding="utf-8")
    return output_path


async def run_transcribe(
    input_path: str,
    output_dir: str,
    model: str,
    language: str,
    host: str = "localhost",
    port: int = 10300,
) -> None:
    """Send WAV audio to Wyoming faster-whisper and write transcript."""
    with wave.open(input_path, "rb") as wav_file:
        rate = wav_file.getframerate()
        width = wav_file.getsampwidth()
        channels = wav_file.getnchannels()
        frames = wav_file.readframes(wav_file.getnframes())

    if not frames:
        raise ValueError("No audio data in WAV file")

    async with AsyncTcpClient(host, port) as client:
        await client.write_event(
            Transcribe(
                name=model or None,
                language=language if language and language != "auto" else None,
            ).event()
        )
        await client.write_event(
            AudioStart(rate=rate, width=width, channels=channels).event()
        )

        chunk_size = rate * width * channels
        for index in range(0, len(frames), chunk_size):
            chunk = frames[index : index + chunk_size]
            await client.write_event(
                AudioChunk(
                    rate=rate,
                    width=width,
                    channels=channels,
                    audio=chunk,
                ).event()
            )

        await client.write_event(AudioStop().event())

        while True:
            event = await client.read_event()
            if event is None:
                break
            if Transcript.is_type(event.type):
                transcript = Transcript.from_event(event)
                loop = asyncio.get_running_loop()
                await loop.run_in_executor(
                    None,
                    write_transcript,
                    Path(output_dir),
                    transcript.text,
                )
                return

    raise RuntimeError("No transcript received from Wyoming server")


def run_tests() -> None:
    class WyomingTranscribeTests(unittest.TestCase):
        def test_write_transcript_creates_output_dir_and_strips_text(self) -> None:
            with tempfile.TemporaryDirectory() as tempdir:
                output_path = write_transcript(
                    Path(tempdir) / "nested", " hello world \n"
                )

                self.assertTrue(output_path.exists())
                self.assertEqual(output_path.read_text(encoding="utf-8"), "hello world")

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(WyomingTranscribeTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send WAV audio to Wyoming faster-whisper STT server"
    )
    parser.add_argument("input_path", help="Path to input WAV audio file")
    parser.add_argument(
        "--output-dir",
        default="/tmp",
        help="Directory to write output.txt transcript",
    )
    parser.add_argument("--model", default="", help="Whisper model name")
    parser.add_argument("--language", default="", help="Language code or 'auto'")
    parser.add_argument("--host", default="localhost", help="Wyoming server host")
    parser.add_argument("--port", type=int, default=10300, help="Wyoming server port")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) == 1 and argv[0] in {"test", "--test"}:
        run_tests()

    args = parse_args(argv)
    try:
        asyncio.run(
            run_transcribe(
                input_path=args.input_path,
                output_dir=args.output_dir,
                model=args.model,
                language=args.language,
                host=args.host,
                port=args.port,
            )
        )
    except (FileNotFoundError, OSError, RuntimeError, ValueError, wave.Error) as exc:
        print(f"wyoming-transcribe: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
