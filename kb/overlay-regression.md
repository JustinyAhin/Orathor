# Recording Overlay Regression Runbook

Use this runbook after changes to recording-overlay visuals, layout lifecycle, animation, or audio-meter publication. It tests Orathor as a compositor-load contributor; it does not diagnose or claim to fix unrelated macOS, display firmware, or hardware faults.

## Setup

1. Build and test current `main` into a disposable DerivedData directory. Test that exact `.app`, not an older installed copy.
2. Use empty Warp and Zed editor inputs. Never submit pasted test text.
3. Quit unrelated GPU-heavy applications. Record uptime, macOS/build, Orathor commit/version, target versions, hardware, and the current display mode.
4. Change refresh rate through System Settings → Displays → Advanced. Verify the selected mode before every group:

   ```bash
   system_profiler SPDisplaysDataType -json \
     | plutil -extract SPDisplaysDataType.0.spdisplays_ndrvs.0._spdisplays_resolution raw -o - -
   ```

5. Store raw artifacts outside the repository. Unified logs and screenshots may contain private application context.

## Collector

Record local start/end timestamps around a fixed window, then run:

```bash
./scripts/capture-overlay-regression.sh \
  --label warp-120-normal \
  --phase normal-paste \
  --target-app /Applications/Warp.app \
  --orathor-app /tmp/orathor-overlay/DerivedData/Build/Products/Debug/Orathor.app \
  --start "2026-08-10 14:00:00" \
  --end "2026-08-10 14:02:00" \
  --sessions 5 \
  --visible-result pass \
  --output /tmp/orathor-overlay/results
```

The collector writes a Markdown summary, the raw matching unified-log window, and the last 500 Orathor diagnostic lines. It reports malformed IOSurface messages separately from backdrop-aware filters, timed fences, invalid window constraints, cursor-disabled noise, and singular matrices.

## Matrix Protocol

Run both ProMotion/120 Hz and fixed 60 Hz. At each refresh rate:

1. **System baseline — 60 seconds:** Orathor, Warp, and Zed quit.
2. For each target, Warp then Zed:
   - **Target only — 60 seconds:** target frontmost, Orathor quit.
   - **Orathor idle — 60 seconds:** target frontmost, Orathor running without recording.
   - **Normal completion — 120 seconds:** complete five speech → stop → paste → dismiss sessions. Verify every paste.
   - **Rapid cancel/restart — 60 seconds:** start, cancel with Escape, then restart within one second; complete five sessions.
   - **Post-dismissal — 60 seconds:** target and Orathor idle after the final dismissal.

Physically watch for full-screen flash, blackout, noise, panel corruption, broken corners, and poor contrast during every active phase. Capture one screenshot while recording in every matrix cell. If a physical artifact occurs, capture a screenshot immediately and record whether the artifact appears in it: screenshot-visible corruption points toward composition; physical-only corruption may be in the display path.

## Pass Criteria

- All 40 active sessions complete; normal sessions paste correctly and every overlay dismisses.
- No visible flash, blackout, noise, or overlay corruption.
- No backdrop-aware vibrant-filter fault correlates with presentation, paste, cancellation, or dismissal.
- Malformed IOSurface counts remain separate from other categories. Flag refresh locking when the active rate materially exceeds target-only/idle baselines and reaches at least 0.8× the selected refresh rate.
- Treat residual system/target-only IOSurface activity as baseline, not proof of an Orathor fault. Investigate any active-only burst before closing the ticket.
- Record all other diagnostic counts without attributing unrelated macOS noise to Orathor.

## Result Record

Environment and results for each completed run belong here. Raw logs and screenshots remain in the temporary artifact directory; include its path in the Bead comment until cleanup.

### 2026-08-10 — Orathor-e6y.4

Pending execution.
