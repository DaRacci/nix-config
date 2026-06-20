#!/usr/bin/env python3
"""Wyoming STT client for Hermes agent.

Receives a WAV file (Hermes pre-converts non-WAV via ffmpeg in
_prepare_local_audio), parses audio metadata from WAV header,
sends to Wyoming faster-whisper server, writes transcript .txt.

Designed for HERMES_LOCAL_STT_COMMAND variable.
"""

import argparse
import asyncio
import os
import sys
import wave

from wyoming.asr import Transcribe, Transcript
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.client import AsyncTcpClient


async def run_transcribe(
    input_path: str,
    output_dir: str,
    model: str,
    language: str,
    host: str = "localhost",
    port: int = 10300,
) -> None:
    """Send WAV audio to Wyoming faster-whisper and write transcript."""
    with wave.open(input_path, "rb") as wf:
        rate = wf.getframerate()
        width = wf.getsampwidth()
        channels = wf.getnchannels()
        frames = wf.readframes(wf.getnframes())

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

        chunk_size = rate * width * channels  # ~1s chunks
        for i in range(0, len(frames), chunk_size):
            chunk = frames[i : i + chunk_size]
            await client.write_event(
                AudioChunk(
                    rate=rate, width=width, channels=channels, audio=chunk
                ).event()
            )

        await client.write_event(AudioStop().event())

        while True:
            event = await client.read_event()
            if event is None:
                break
            if Transcript.is_type(event.type):
                transcript = Transcript.from_event(event)
                output_path = os.path.join(output_dir, "output.txt")
                with open(output_path, "w") as f:
                    f.write(transcript.text.strip())
                return

    sys.exit(1)


def main() -> None:
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
    args = parser.parse_args()

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


if __name__ == "__main__":
    main()
