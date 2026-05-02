# Hotkey QA Checklist

## Goal
Validate that Yapper's dictation lifecycle, local cleanup, sound cues, and output behavior feel deterministic under real hotkey usage.

## Preconditions
- Build and run the release app binary
- Confirm microphone, accessibility, and input monitoring permissions are granted
- Have a text field selected for insertion tests
- Have clipboard fallback available for non-editable target tests

## Core Flows
- Single tap starts dictation, plays the start sound, and shows the recording pill
- Speaking updates the pill with live transcript text without shrinking or jumping
- Silence auto-stops dictation when silence detection is enabled
- Single tap start then single tap stop completes cleanly with a processing state followed by completion
- Completion plays the success sound and shows `Inserted` or `Copied`
- Starting while the model is still loading fails clearly and returns to ready after dismissal

## Output Paths
- Selected text field insertion succeeds through accessibility mode
- Clipboard fallback succeeds when direct insertion is unavailable
- Completion pill distinguishes inserted output vs clipboard fallback
- Cleanup enabled: short snippets receive fast heuristic punctuation/casing
- Cleanup enabled: longer snippets use the local model when the bundled resources are present
- Cleanup disabled: raw transcript is inserted without punctuation/casing changes

## Rapid Input / Edge Cases
- Repeated single taps do not leave the pill stuck off-screen or in an incorrect state
- Rapid cancel/restart returns the app to an idle-ready state between attempts
- Tapping during processing queues a fresh recording after the current insertion finishes
- Returning from System Settings after permission changes recovers hotkey readiness without relaunch
- Quit while recording discards the active session without inserting partial text

## UI Checks
- Recording pill text stays centered while live transcript updates
- Waveform remains visible and stable during speech
- Pill height, text size, and padding match the scaled Figma metrics
- Canceled state is visible and understandable
- Failed state is visible and understandable

## Log Any Failures
- Trigger used
- Expected behavior
- Actual behavior
- Whether a text field was focused
- Whether insertion happened via accessibility or clipboard
- Whether cleanup was enabled and whether the snippet was above the model-cleanup threshold
- Screenshot or screen recording if the issue is visual
