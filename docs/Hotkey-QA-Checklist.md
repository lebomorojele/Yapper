# Hotkey QA Checklist

## Goal
Validate that Yapper's recording lifecycle, cancel flows, and output behavior feel deterministic under real hotkey usage.

## Preconditions
- Build and run the release app binary
- Confirm microphone, accessibility, and input monitoring permissions are granted
- Have a text field selected for insertion tests
- Have clipboard fallback available for non-editable target tests

## Core Flows
- Single tap starts dictation, shows recording pill, and inserts transcript into the selected text field
- Single tap start then single tap stop completes cleanly with a completion pill
- Double tap starts smart mode, records, then shows the option-selection pill
- Smart mode accepts keyboard shortcuts `1`, `2`, `3`, `4` for option selection
- Smart mode cancel keeps the raw transcript and shows the expected completion behavior
- Long press starts meeting mode and does not stop automatically on silence
- Meeting mode only stops when manually ended

## Output Paths
- Selected text field insertion succeeds through accessibility mode
- Clipboard fallback succeeds when direct insertion is unavailable
- Completion pill distinguishes inserted output vs clipboard fallback
- Meeting recordings appear in shared history after stopping
- Transcript export respects the current save location and can be revealed in Finder

## Rapid Input / Edge Cases
- Repeated single taps do not leave the pill stuck off-screen or in an incorrect state
- Switching quickly from single tap to double tap shows a clear canceled/discarded state
- Starting dictation, then hold-starting meeting mode, cleanly cancels the first session
- Rapid cancel/restart returns the app to an idle-ready state between attempts
- Returning from System Settings after permission changes recovers hotkey readiness without relaunch

## UI Checks
- Recording pill text stays centered while live transcript updates
- Waveform remains visible and stable during speech
- Option-selection pill is correctly sized and not clipped
- Canceled state is visible and understandable
- History rows show the right type, duration, and timestamp metadata

## Log Any Failures
- Trigger used
- Expected behavior
- Actual behavior
- Whether a text field was focused
- Whether insertion happened via accessibility or clipboard
- Screenshot or screen recording if the issue is visual
