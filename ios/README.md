# WHOOP Timer for iPhone

A companion for a WHOOP 5.0 already connected to the iPhone. Start after a countdown or at a selected local date and time, choose how long the strap should repeat short pulses, and stop at any time. Requires iOS 17 or newer.

## First device test

1. Confirm the official WHOOP app can sync. Leave the Windows controller disconnected.
2. Open WHOOP Timer, allow Bluetooth access, and select your WHOOP. The companion looks for the device already connected to iOS. If none is listed, open the official app, let it connect, then return and tap **Refresh**.
3. Tap **Test Vibration**, confirm one pulse, and tap **I felt it** if you feel the buzz. If iOS presents a new system pairing prompt, cancel it and disconnect.
4. Choose a countdown preset or enter custom seconds, then tap **Start Timer**. For a scheduled alarm, choose **At a time**, select a date and time, and tap **Arm Alarm**. The display stays awake while the timer is armed or running. Locking the phone or switching away cancels it.
5. Tap **Ringtone** to choose and preview Steady, Double, or Swell. Each uses a different wrist cadence. **Also play sound on iPhone** adds the matching chime through the phone when sound is on.
6. In **Ring until dismissed** mode, the app repeats until it sees a live double-tap, you tap **Stop**, the connection is lost, or its selected maximum runtime is reached. To check for tap support, open **Strap** after testing vibration, double-tap the top of the sensor, and look for **Double-tap detected**. Double-tap dismissal on the target sensor has yet to be verified.
7. After testing, check that the official WHOOP app still syncs.

The iPhone companion attaches to the existing iOS connection. The WHOOP app and the timer have separate purposes, and coexistence during a run still needs a target-device check. The Swift protocol sends the verified one-shot command and waits for a final reply before the next pulse. If the strap declines a fast pulse, the timer enforces at least 1.5 seconds between pulses for the rest of that run. A further refusal stops the timer and retains the connection. The app listens for fresh strap tap events through the WHOOP notification characteristic.

## Build and install

On macOS, open `WhoopTimer.xcodeproj` in Xcode. Set a Personal Team under **Signing & Capabilities**, choose the USB-connected iPhone, enable Developer Mode on the phone if prompted, and Run. Free personal provisioning expires after seven days. [Apple on-device build instructions](https://developer.apple.com/documentation/xcode/building-and-running-an-app) · [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

From Windows, a hosted macOS runner can build the unsigned app. In a repository containing this `ios` folder and the root `.github/workflows/build-iphone.yml`, manually run **Build iPhone companion**. The runner builds against the iPhone SDK, checks the captured protocol fixtures, and publishes an unsigned IPA as an artifact. GitHub does not need an Apple Account login or signing key for this build. Standard public GitHub runners are free. Check included usage and enforce a zero-overage budget before running on a private repository. [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

Download and unzip the workflow artifact. With iTunes and iLoader installed on Windows, connect the unlocked iPhone over USB and tap **Trust** if prompted. Open iLoader, choose your phone, sign in with your Apple Account, and use **Import IPA** to select `WhoopTimer-unsigned.ipa`. Enable Developer Mode and trust the developer profile if prompted on the phone. Enter Apple credentials yourself in iLoader. [Official iLoader download and instructions](https://iloader.app/) · [Apple Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
