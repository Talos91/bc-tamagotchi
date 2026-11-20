# Queued for next week (Daniele, 2026-11-21 ~00:45, at the bar)

Owner words (verbatim): "Next week should change the loading screen, to say black cabin (possibly a still of the entrance) instead of godmother loading aaand we need to turn this into an apk for both iPhone and androdi"

1. **Loading screen (🖼️ UI, Opus):** replace the Godot boot splash / loading text with a Black Cabin one: "Black Cabin", ideally over a still of the entrance (photos docs/venue/photos/2026-11-20-entrance-round/ or a render of the entrance room). Covers project.godot boot splash, the web export's HTML loading screen (custom HTML shell / progress bar), and any in-game loading text. Phone portrait first.
2. **Native apps (🛠️ tech, Opus; needs Daniele's accounts):**
   - Android: Godot Android export → APK for sideload/testing + AAB for Play Store. Needs the Android SDK/JDK on the PC, a release keystore (Daniele keeps it), and a Play Console account ($25) for the store.
   - iPhone: iOS has no APK. Godot exports an Xcode project, which needs a Mac with Xcode to build, an Apple Developer account ($99/yr), then TestFlight → App Store. No Mac on hand → options: a cloud Mac (e.g. Codemagic or GitHub Actions macOS runner) or keep iPhone on the PWA (Add to Home Screen).
   - Open calls for Daniele: store accounts and who owns them, app name/icon, whether presence/QR/web push behave the same natively (push → FCM/APNs instead of web push).
