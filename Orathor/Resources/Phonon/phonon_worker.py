"""Orathor's private, versioned stdio bridge to the pinned Phonon-2 runtime.

Audio is mono float32 LE at 16 kHz. The app owns microphone access and capture.
Only download mode may access the network; serving uses a verified local model.
"""
from __future__ import annotations

import argparse
import base64
import contextlib
import hashlib
import json
import sys
from pathlib import Path

PROTOCOL_VERSION = 1
CONTAINER_SHA256 = "4b6bfa3a12cc3c4e0a54f2ab3ec4ca7a842b09e5c7ecfc8e7ca0ac6cc8c11468"
MAX_MESSAGE_BYTES = 65536
MAX_AUDIO_BYTES = 32000


def verify_model(model_dir: Path) -> None:
    for name in ("config.json", "packed_manifest.json", "model.fermion"):
        if not (model_dir / name).is_file():
            raise RuntimeError("Phonon files are missing. Download the engine again in Settings.")
    with (model_dir / "model.fermion").open("rb") as container:
        digest = hashlib.file_digest(container, "sha256").hexdigest()
    if digest != CONTAINER_SHA256:
        raise RuntimeError("Phonon model verification failed. Download the engine again in Settings.")


def download() -> None:
    from fermion.transcribe import _resolve
    from fermion._speech import backends, fetch

    repo, key, pin, _ = _resolve("phonon-2")
    backends.require_engine_for(backends.resolve("Orathor Phonon setup"), pin["backend"])
    path = fetch.ensure(repo, key, pin)
    verify_model(path)
    print("Phonon model download verified.", file=sys.stderr)


class Worker:
    def __init__(self, model_dir: Path, emit):
        self.model_dir = model_dir
        self.emit = emit
        self.speech = None
        self.session = None
        self.session_id = None

    def _partial(self, text: str) -> None:
        whole = " ".join(part for part in (self.session.transcript, text) if part)
        self.emit({"type": "partial", "session": self.session_id, "text": whole})

    def _final(self, _text: str) -> None:
        self.emit({"type": "partial", "session": self.session_id, "text": self.session.transcript})

    def handle(self, request: dict) -> dict:
        op = request.get("op")
        if op == "load":
            if self.speech is None:
                verify_model(self.model_dir)
                from fermion._speech import backends
                from fermion._speech.live import warm_up
                self.speech = backends.load("mlx", self.model_dir, profile="five-value", backend="phonon2-five-value", quiet=True)
                warm_up(self.speech)
            return {"protocol": PROTOCOL_VERSION}
        if self.speech is None:
            raise RuntimeError("Phonon is not loaded.")
        if op == "start":
            if self.session is not None:
                raise RuntimeError("A Phonon recording is already active.")
            session_id = request.get("session")
            if not isinstance(session_id, str) or not session_id:
                raise ValueError("A recording identifier is required.")
            from fermion._speech.live import LiveSession
            self.session_id = session_id
            self.session = LiveSession(self.speech, on_partial=self._partial, on_final=self._final)
            return {}
        if self.session is None or request.get("session") != self.session_id:
            raise RuntimeError("This Phonon recording is no longer active.")
        if op == "audio":
            import numpy as np
            raw = base64.b64decode(request.get("audio", ""), validate=True)
            if not raw or len(raw) > MAX_AUDIO_BYTES or len(raw) % 4:
                raise ValueError("Invalid Phonon audio frame.")
            block = np.frombuffer(raw, dtype="<f4")
            if not np.isfinite(block).all():
                raise ValueError("Phonon audio contains invalid samples.")
            self.session.feed(block)
            return {}
        if op == "finish":
            text = self.session.finish()
            self.session = None
            self.session_id = None
            return {"text": text}
        if op == "abort":
            self.session = None
            self.session_id = None
            return {}
        raise ValueError("Unknown Phonon command.")


def serve(model_dir: Path) -> None:
    # Imported libraries occasionally print status to stdout. Preserve the
    # protocol stream separately, and send all their output to stderr.
    protocol_output = sys.stdout
    def emit(message):
        protocol_output.write(json.dumps(message, ensure_ascii=False) + "\n")
        protocol_output.flush()
    worker = Worker(model_dir, emit)
    with contextlib.redirect_stdout(sys.stderr):
        while True:
            line = sys.stdin.buffer.readline(MAX_MESSAGE_BYTES + 1)
            if not line:
                return
            if len(line) > MAX_MESSAGE_BYTES:
                raise ValueError("Phonon message exceeds the protocol limit.")
            request_id = None
            try:
                request = json.loads(line)
                if not isinstance(request, dict) or not isinstance(request.get("id"), str):
                    raise ValueError("Invalid Phonon request.")
                request_id = request["id"]
                result = worker.handle(request)
                emit({"type": "reply", "id": request_id, "ok": True, **result})
            except Exception as exc:
                emit({"type": "reply", "id": request_id, "ok": False, "error": str(exc)})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--model-dir", type=Path)
    args = parser.parse_args()
    if args.download:
        download()
    elif args.model_dir:
        serve(args.model_dir)
    else:
        parser.error("--model-dir or --download is required")


if __name__ == "__main__":
    main()
