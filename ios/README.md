# WHOOP Timer for iPhone

A companion for a WHOOP 5.0 already connected to the iPhone. Set a countdown, choose how long the strap should repeat short pulses, adjust the spacing, and stop at any time. Requires iOS 17 or newer.

## First device test

1. Confirm the official WHOOP app can sync. Leave the Windows controller disconnected.
2. Open WHOOP Timer, allow Bluetooth access, and select your WHOOP. The companion looks for the device already connected to iOS. If none is listed, open the official app, let it connect, then return and tap **Refresh**.
3. Tap **Test Vibration**, confirm one pulse, and tap **I felt it** if you feel the buzz. If iOS presents a new system pairing prompt, cancel it and disconnect.
4. Use **Start Timer** while keeping WHOOP Timer on screen. Closing or switching away from the app cancels the run and releases its local connection. The system display stays awake during a run.
5. After the test, confirm the official WHOOP app still syncs.

The Swift protocol implementation uses the same one-shot command as the Windows app and waits for a matching final reply before sending another pulse. iPhone Bluetooth behavior and coexistence with the official app still need a device test. Scheduling overnight with the iPhone locked is outside this version.

## Build and install

On macOS, open `WhoopTimer.xcodeproj` in Xcode. Set a Personal Team under **Signing & Capabilities**, choose the USB-connected iPhone, enable Developer Mode on the phone if prompted, and Run. Free personal provisioning expires after seven days. [Apple on-device build instructions](https://developer.apple.com/documentation/xcode/building-and-running-an-app) · [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

From Windows, a hosted macOS runner can build the unsigned app. In a repository containing this `ios` folder and the root `.github/workflows/build-iphone.yml`, manually run **Build iPhone companion**. The runner builds against the iPhone SDK, checks the captured protocol fixtures, and publishes an unsigned IPA as an artifact. GitHub does not need an Apple Account login or signing key for this build. Standard public GitHub runners are free. Check included usage and enforce a zero-overage budget before running on a private repository. [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

Download and unzip the workflow artifact. With iTunes and iLoader installed on Windows, connect the unlocked iPhone over USB and tap **Trust** if prompted. Open iLoader, choose your phone, sign in with your Apple Account, and use **Import IPA** to select `WhoopTimer-unsigned.ipa`. Enable Developer Mode and trust the developer profile if prompted on the phone. Enter Apple credentials yourself in iLoader. [Official iLoader download and instructions](https://iloader.app/) · [Apple Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
