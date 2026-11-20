# WHOOP Timer for iPhone

A companion for a WHOOP 5.0 already connected to the iPhone. Start after a countdown or at a selected local date and time, choose how long the strap should repeat short pulses, and stop at any time. Requires iOS 17 or newer.

## First device test

1. Confirm the official WHOOP app can sync. Leave the Windows controller disconnected.
2. Open WHOOP Timer and allow Bluetooth access. It automatically connects to the remembered WHOOP already connected to iOS, or to the only currently connected WHOOP on first use. If no strap appears, let the official app connect and then return to WHOOP Timer. When the choice is ambiguous, select your strap in the connection panel. If iOS presents a new system pairing prompt, cancel it.
3. Tap **Start Timer** to reuse your last countdown, choose a preset, or enter custom seconds. To arm a scheduled alarm, choose **At a time**, select a date and time, and tap **Arm Alarm**. The display stays awake while the timer is armed or running. Locking the phone or switching away cancels it.
4. **Native Burst** is the default wrist vibration. **Preview** sends one optional burst. **Also play sound on iPhone** adds the matching chime through the phone when sound is on.
5. In **Ring until dismissed** mode, the app repeats until it sees a live double-tap, you tap **Stop**, the connection is lost, or its selected maximum runtime is reached. To check for tap support, use **Preview**, open **Strap**, double-tap the top of the sensor, and look for **Double-tap detected**. Double-tap dismissal on the target sensor has yet to be verified.
6. After testing, check that the official WHOOP app still syncs.

The iPhone companion attaches to the existing iOS connection. It opens the vibration session only when a preview or alarm is due. Native Burst uses the Maverick repeat field with the waveform the user confirmed on their WHOOP. It waits for a final reply and leaves at least three seconds between burst commands. A refusal stops the timer and retains the connection. The app listens for fresh strap tap events through the WHOOP notification characteristic.

## Build and install

On macOS, open `WhoopTimer.xcodeproj` in Xcode. Set a Personal Team under **Signing & Capabilities**, choose the USB-connected iPhone, enable Developer Mode on the phone if prompted, and Run. Free personal provisioning expires after seven days. [Apple on-device build instructions](https://developer.apple.com/documentation/xcode/building-and-running-an-app) · [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

From Windows, a hosted macOS runner can build the unsigned app. In a repository containing this `ios` folder and the root `.github/workflows/build-iphone.yml`, manually run **Build iPhone companion**. The runner builds against the iPhone SDK, checks the captured protocol fixtures, and publishes an unsigned IPA as an artifact. GitHub does not need an Apple Account login or signing key for this build. Standard public GitHub runners are free. Check included usage and enforce a zero-overage budget before running on a private repository. [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

Download and unzip the workflow artifact. With iTunes and iLoader installed on Windows, connect the unlocked iPhone over USB and tap **Trust** if prompted. Open iLoader, choose your phone, sign in with your Apple Account, and use **Import IPA** to select `WhoopTimer-unsigned.ipa`. Enable Developer Mode and trust the developer profile if prompted on the phone. Enter Apple credentials yourself in iLoader. [Official iLoader download and instructions](https://iloader.app/) · [Apple Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
