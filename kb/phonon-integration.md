# Phonon 2 integration

Phonon is an optional local English engine. Apple remains the default. The
assessment of existing recordings found faster file decoding and earlier live
text, alongside persistent technical-name errors. A vocabulary list cannot bias
the released Phonon-2 decoder; the existing personalizer still runs after
transcription, and no broad phonetic replacements were introduced.

## Setup and distribution

Settings downloads an isolated runtime under
`~/Library/Application Support/segbedji.Orathor/Phonon`. No system Python,
Homebrew, shell configuration, API key, or benchmark directory is used.

The bootstrap is uv 0.12.21, checked against a pinned archive SHA-256. It installs
managed CPython 3.13.12 and the hashed requirements in
`Orathor/Resources/Phonon/phonon-requirements.txt`. All packages are installed from
wheels with hash verification. The direct version pins are in the adjacent `.in`
file; regenerate the lock on a supported Apple silicon Mac using `uv pip compile
--python-version 3.13 --generate-hashes --only-binary :all:`.

Fermion Research 0.2.3 downloads the Phonon-2 artifact using its pinned checksum
and verifies unpacked members. Orathor also checks the model container SHA-256
before loading. The installed marker is written only after setup succeeds.
Interrupted setup can be retried. Dictation starts the helper with a local model
path and Hugging Face offline mode; recordings never go to a server.

The model is 164 MB, but the Python/MLX dependencies need additional download and
disk space. The verified setup occupies 2.4 GB including its download caches;
allow about 3 GB of disk space. The full runtime uses approximately 3 GB of memory while loaded.
This integration intentionally uses the evaluated MLX engine on Apple silicon.

## Dictation lifecycle

`PhononSpeechService` implements the same protocol as the existing engines.
`PhononWorker` runs the bundled helper through private stdin/stdout pipes. The
versioned JSON protocol contains request and recording identifiers; late
partials from a previous recording are ignored. Pipe writes run off the main
actor. Inference stays in the separate process.

The app captures microphone audio, converts it to 16 kHz mono Float32, and queues
50 ms frames. The queue is bounded to 30 seconds of backlog. Overflow or invalid
audio fails visibly instead of losing audio silently. Live decoding uses the
same Fermion `LiveSession` tested in the assessment, with its partial cadence,
silence segmentation, and 30-second segment cap.

Preparation finishes before microphone capture. Releasing the shortcut during
preparation cancels the pending recording. Key-up drains the audio queue before
requesting finalization. The loaded model is reused between recordings and
released after two minutes idle or when switching engines. Transient failures
during a recording use the existing saved-audio Apple fallback in English.
History retains requested and actual output engines. Cancellation skips history
and insertion through the existing recording flow.

## Verification

`PhononSpeechServiceTests` covers queue draining, resampling, bounded buffering,
late partials, cancellation during preparation, failure propagation, warm reuse
behavior, and engine persistence. The opt-in `PhononIntegrationTests` installs
the managed runtime and replays local saved recordings at real-time speed through
the actual Swift service, asserting live partials, final text, model-process
reuse, and shutdown. Supply `ORATHOR_PHONON_REPLAY_MANIFEST` and optionally
`ORATHOR_PHONON_REPLAY_OUTPUT` to the test host. Private recordings and resulting
transcripts stay outside the repository.

For an Xcode CLI run, prefix test-host environment variables with `TEST_RUNNER_`:

```sh
TEST_RUNNER_ORATHOR_PHONON_REPLAY_MANIFEST=/absolute/path/manifest.json \
TEST_RUNNER_ORATHOR_PHONON_REPLAY_OUTPUT=/absolute/path/results.json \
xcodebuild -scheme Orathor -configuration Debug -destination 'platform=macOS' \
  -parallel-testing-enabled NO test
```

On 2026-09-30, all 48 tests passed, including a fresh managed installation and
six saved-recording replays through the actual service. In the final warm replay
on the M3 Max, median first partial was 0.73 seconds and median finalization was
0.05 seconds. One model process served all six recordings and exited after
shutdown. These are timings for the selected clips, not an accuracy claim.
Debug and Release builds also passed.

## Attribution

Phonon-2 is developed by [Fermion Research](https://www.fermionresearch.com/models/phonon-2/)
and derives from [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3).
The weights are licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Orathor uses the released weights without modification. Fermion's notice is
bundled as `Phonon-2-NOTICE.txt`; downloaded packages retain their license metadata.
Fermion's runtime is Apache-2.0; MLX and mlx-audio are MIT-licensed. See the notice
for the upstream weight changes, training-data credits, and runtime dependencies.
