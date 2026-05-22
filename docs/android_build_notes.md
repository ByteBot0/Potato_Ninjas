# Android Build Notes

HookRex Arena has the first Android-readiness layer in place:

- Landscape orientation project setting
- Touch-control overlay scene
- Left virtual joystick for movement
- Right aim stick for aim/fire testing
- Jump, fire, and hook buttons
- Desktop toggle with `T` for testing the overlay before exporting

Remaining Android export work:

1. Install Godot Android export templates.
2. Configure Android SDK/JDK paths in Godot editor settings.
3. Create an Android export preset.
4. Set package name, app name, icons, and signing options.
5. Export APK.
6. Sideload to phone.
7. Tune touch button placement and scale on real hardware.
