# WHOOP Timer for iPhone

A companion for a WHOOP 5.0 already connected to the iPhone. Start after a countdown or at a selected local date and time, choose how long the strap should repeat short pulses, and stop at any time. Requires iOS 17 or newer.

## First device test

1. Confirm the official WHOOP app can sync. Leave the Windows controller disconnected.
2. Open WHOOP Timer and allow Bluetooth access. It automatically connects to the remembered WHOOP already connected to iOS, or to the only currently connected WHOOP on first use. If no strap appears, let the official app connect and then return to WHOOP Timer. When the choice is ambiguous, select your strap in the connection panel. If iOS presents a new system pairing prompt, cancel it.
3. Tap **Start Timer** to reuse your last countdown, choose a preset, or enter custom seconds. To arm a scheduled alarm, choose **At a time**, select a date and time, and tap **Arm Alarm**. The display stays awake while the app is active. Leaving the screen keeps the alarm armed and reports a phone backup if one is registered.
4. **Native Burst** is the default wrist vibration. **Preview** sends one optional burst. **Also play sound on iPhone** adds the matching chime through the phone when sound is on.
5. In **Ring until dismissed** mode, the app repeats until it sees a live double-tap, you tap **Stop**, the connection is lost, or its selected maximum runtime is reached. To check for tap support, use **Preview**, open **Strap**, double-tap the top of the sensor, and look for **Double-tap detected**. Double-tap dismissal on the target sensor has yet to be verified.
6. After testing, check that the official WHOOP app still syncs.

The iPhone companion attaches to the existing iOS connection. It opens the vibration session only when a preview or alarm is due. Native Burst uses the Maverick repeat field with the waveform the user confirmed on their WHOOP. It waits for a final reply and leaves at least three seconds between burst commands. A refusal stops the timer and retains the connection. The app listens for fresh strap tap events through the WHOOP notification characteristic.

## Background and locked-screen behavior

On iOS 26 and newer, leave **iPhone backup alarm** enabled and allow Alarms when prompted. Wait for **iPhone backup set** before leaving the app. iOS registers a system alarm eight seconds after the target time. The app cancels it if it receives a successful wrist response first or you press Stop. If iOS suspends or force-quits the app before the first burst, the system alarm can still ring on the iPhone. Reopen the app to cancel a pending phone backup.

WHOOP Timer keeps its Bluetooth connection while an alarm is armed in the background and requests a short execution window for an imminent alarm. iOS can still suspend this app. Background wrist timing and device behavior need a live check, and swiping the app card away can end its wrist session. The iPhone system alarm is the fallback in that case. [Apple AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit) · [Core Bluetooth background execution](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)

## Build and install

On macOS, open `WhoopTimer.xcodeproj` in Xcode. Set a Personal Team under **Signing & Capabilities**, choose the USB-connected iPhone, enable Developer Mode on the phone if prompted, and Run. Free personal provisioning expires after seven days. [Apple on-device build instructions](https://developer.apple.com/documentation/xcode/building-and-running-an-app) · [Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

From Windows, a hosted macOS runner can build the unsigned app. In a repository containing this `ios` folder and the root `.github/workflows/build-iphone.yml`, manually run **Build iPhone companion**. The runner builds against the iPhone SDK, checks the captured protocol fixtures, and publishes an unsigned IPA as an artifact. GitHub does not need an Apple Account login or signing key for this build. Standard public GitHub runners are free. Check included usage and enforce a zero-overage budget before running on a private repository. [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

Download and unzip the workflow artifact. With iTunes and iLoader installed on Windows, connect the unlocked iPhone over USB and tap **Trust** if prompted. Open iLoader, choose your phone, sign in with your Apple Account, and use **Import IPA** to select `WhoopTimer-unsigned.ipa`. Enable Developer Mode and trust the developer profile if prompted on the phone. Enter Apple credentials yourself in iLoader. [Official iLoader download and instructions](https://iloader.app/) · [Apple Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
