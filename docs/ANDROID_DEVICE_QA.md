# Android ARMv7 Device QA

This checklist is the physical-device acceptance gate for the **Android ARMv7 Debug** export. A successful headless test or APK export does not replace this pass.

## Required device evidence

Record the exact device model, Android version, ABI list, APK SHA-256, test date, and tester. Keep one logcat capture for the full session and note every failure with the step number.

Before testing, verify the installed package reports `armeabi-v7a` and that the APK contains no other native ABI. Do not infer 32-bit compatibility from the CPU model alone.

## 1. Install and launch

- [ ] Install the debug APK over USB with Android Debug Bridge.
- [ ] Confirm installation succeeds without an ABI or package error.
- [ ] Launch from the app icon; verify the title/home screen appears.
- [ ] Start Classic and verify the game enters landscape orientation.
- [ ] Start Frontier and verify the larger map loads without a startup crash.
- [ ] Confirm the game remains visible when the status/navigation bars are hidden.

Record cold-launch time and any import, shader, audio, or asset errors.

## 2. Touch controls

- [ ] Left joystick moves in all four cardinal directions.
- [ ] Diagonal movement is normalized; it is not faster than cardinal movement.
- [ ] The outer joystick threshold enables sprint and releasing it disables sprint.
- [ ] Attack can be held while the other finger moves the joystick.
- [ ] Interact, Dash, Cleave, and Rally each trigger once per intended input.
- [ ] Releasing one finger does not cancel another finger's action.
- [ ] Lifting or cancelling every finger releases all synthetic input.
- [ ] Touching pause opens the pause menu; the controls disappear while it is open.
- [ ] Closing pause restores the touch controls without stuck movement or actions.

Repeat the movement + attack test while moving diagonally. Repeat ability presses while moving. Note any accidental UI activation or missed hit target.

## 3. Safe areas and overlays

- [ ] Joystick, pause control, and action buttons stay inside the usable display area.
- [ ] No control is hidden by a camera cutout, rounded corner, or system gesture region.
- [ ] Open map, technology, outpost, construction queue, help, and event-decision overlays.
- [ ] Verify virtual controls do not cover or intercept those overlays.
- [ ] Rotate is not expected: the game is landscape-only. Confirm returning from Android system UI restores the same orientation and layout.

## 4. Lifecycle and recovery

- [ ] Pause and resume repeatedly.
- [ ] Send the app to the background, wait 30 seconds, and resume.
- [ ] Lock and unlock the device while the game is running.
- [ ] Confirm the game does not resume with stuck joystick, attack, interact, or sprint input.
- [ ] Save, return to the title screen, reload, and verify the campaign state.
- [ ] Force-stop and relaunch; verify the last completed save remains loadable.

## 5. Sustained gameplay and performance

Run at least 20 minutes on the target device:

- [ ] Play Classic through multiple day/night transitions.
- [ ] Trigger a night wave with multiple villagers, enemies, buildings, and projectiles active.
- [ ] Repeat in Frontier with exploration/fog and faction activity enabled.
- [ ] Watch for sustained frame-time degradation, input latency, audio dropouts, overheating, or OS process termination.
- [ ] Confirm memory use does not grow continuously during the session.
- [ ] Confirm the device remains responsive after returning to the title screen.

Do not accept a single average-FPS number as proof of smoothness. Record visible stutters and, where available, frame-time percentiles and peak memory.

## 6. Failure capture

Capture logs immediately after reproducing a failure:

```sh
adb logcat -c
# Reproduce the issue, then:
adb logcat -d -v threadtime > android-device-qa-logcat.txt
adb shell dumpsys meminfo com.shimleabyte.holdthekeep
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.build.version.release
```

Also record:
- Exact steps to reproduce.
- Whether the failure is repeatable.
- Whether it occurs after background/resume or only during a fresh launch.
- Screenshot or short recording for layout/touch failures.
- Whether the same scenario works on desktop.

## Acceptance

The Android workstream is **not device-validated** until all required sections pass on the intended ARMv7 device. Any crash, stuck input, inaccessible control, save corruption, or sustained severe slowdown blocks acceptance. Record known limitations explicitly rather than marking the device pass.
