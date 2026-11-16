# Performance

Inlet's v1 speed target is simple: the grid should be on screen less than 100 ms after you press the grid hotkey (Option + Space by default).

This file explains what is measured, how to measure it in Instruments, and what the numbers do and do not mean.

## What is measured

`Inlet/Performance/InletSignpost.swift` defines one os_signpost interval:

| Field | Value |
| --- | --- |
| Subsystem | `com.freezingshock.Inlet` |
| Category | `Performance` |
| Interval | `Hotkey to visible` |

The interval starts in `AppDelegate` when the grid hotkey handler runs. It ends in `OverlayController.show()`, right after the overlay panel is ordered onto the screen.

So the interval covers: the hotkey callback, toggling the overlay, and putting the panel on screen. It does not cover the time from your physical key press to the callback, which is handled by macOS and the KeyboardShortcuts package. It also does not measure the first pixel SwiftUI draws into the panel. Treat it as a close upper bound on the software part of the delay, not as a camera-accurate measure.

Pressing the hotkey while the grid is open closes it. That press cancels the interval, so it is not counted.

## Recording it in Instruments

I wrote these steps without running Xcode here. Check the menu and template names the first time you use them, since they can change between Xcode versions.

1. Open the project in Xcode and choose **Product > Profile** (⌘I). Use the **Release** configuration when you can, because Debug builds run slower and skew the numbers.
2. In the template chooser, pick **Logging** or **Blank**.
3. If you used Blank, add the **os_signpost** instrument (older Xcode calls it **Points of Interest**).
4. Click Record, wait for Inlet to launch, then press Option + Space about 20 times, closing the grid between presses.
5. Stop the recording. Select the **Hotkey to visible** intervals in the track and read their durations. Filter on subsystem `com.freezingshock.Inlet` if you see other signposts.

To check the numbers without Instruments, run Inlet and open **Console.app**. Filter for `subsystem:com.freezingshock.Inlet category:Performance`.

## Reading the result

- Target: the median should be under 100 ms, and no single press should be far above it.
- Start with a Release build on a Mac that has been running for a while. The first press after launch may be slower because the icon cache is still filling.
- If the median is over 100 ms, check what else runs on the main thread during the press. The app scan never runs on open, by design.

## Speed of the app scan

`InletTests/AppScannerTests.swift` has a `testScanTiming` test that measures a full `/Applications` scan with `measure`. Xcode records the result in the test report. The test does not fail when the scan is slow. Compare the numbers between runs on the same Mac.

To run the unit tests locally:

```sh
xcodebuild test -project Inlet.xcodeproj -scheme Inlet -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Not covered yet

- UI tests for launch, search, and Escape are not in the project yet. They need a new UI test target.
- The quick panel (Control + Option + Space) has no signpost yet.
