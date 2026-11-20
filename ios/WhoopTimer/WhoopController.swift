import Combine
@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class WhoopController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum Activity: Equatable { case idle, testing, countdown, vibrating }
    private enum Expected: Equatable { case hello, subscription, pulse(UInt8) }

    @Published private(set) var devices: [CBPeripheral] = []
    @Published private(set) var activity = Activity.idle
    @Published private(set) var status = "Checking Bluetooth…"
    @Published private(set) var message = ""
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var testAcknowledged = false
    @Published private(set) var confirmed = false
    @Published private(set) var remaining = 0
    @Published private(set) var log: [String] = []

    private let serviceID = CBUUID(string: Puffin.service)
    private let writeID = CBUUID(string: Puffin.write)
    private let responseID = CBUUID(string: Puffin.notify)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var command: CBCharacteristic?
    private var response: CBCharacteristic?
    private var sessionReady = false
    private var expected: Expected?
    private var sequence: UInt8 = 1
    private var responses = HapticResponses()
    private var clockTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func refresh() {
        guard let central, central.state == .poweredOn, peripheral == nil else { return }
        devices = central.retrieveConnectedPeripherals(withServices: [serviceID])
        status = devices.isEmpty ? "No WHOOP connection found" : "Select your WHOOP"
        message = devices.isEmpty ? "Open the official WHOOP app, let it sync, then tap Refresh." : ""
    }

    func connect(_ selected: CBPeripheral) {
        guard let central, central.state == .poweredOn, peripheral == nil,
              devices.contains(where: { $0.identifier == selected.identifier }) else { return }
        peripheral = selected
        selected.delegate = self
        connecting = true
        status = "Connecting…"
        message = ""
        central.connect(selected, options: nil)
        startTimeout(seconds: 12, message: "Couldn’t open the shared Bluetooth connection.")
    }

    func disconnect() {
        let selected = peripheral
        clearLink()
        if let selected { central?.cancelPeripheralConnection(selected) }
        status = "Disconnected"
        message = ""
        devices = []
    }

    func test() {
        guard activity == .idle, connected, let peripheral, let command else { return }
        activity = .testing
        testAcknowledged = false
        confirmed = false
        if sessionReady {
            sendPulse()
        } else {
            expected = .hello
            peripheral.writeValue(Puffin.hello, for: command, type: .withResponse)
            startTimeout(seconds: 5, message: "WHOOP did not acknowledge the session setup.")
        }
    }

    func confirmVibration() {
        guard activity == .idle, testAcknowledged, connected else { return }
        confirmed = true
        message = "Ready to run a timer."
    }

    func start(delay: Int, duration: Int, spacing: Double) {
        guard activity == .idle, confirmed, connected, sessionReady,
              (0...3600).contains(delay), (1...300).contains(duration), (0.5...10).contains(spacing) else {
            return
        }
        message = ""
        activity = delay == 0 ? .vibrating : .countdown
        remaining = delay == 0 ? duration : delay
        let startAt = ProcessInfo.processInfo.systemUptime + Double(delay)
        let endAt = startAt + Double(duration)
        clockTask = Task { [weak self] in
            var nextPulse = startAt
            while !Task.isCancelled {
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if now >= endAt {
                    self.finish("Timer complete.")
                    return
                }
                if now >= startAt {
                    if self.activity != .vibrating { self.activity = .vibrating }
                    let seconds = Int(ceil(endAt - now))
                    if self.remaining != seconds { self.remaining = seconds }
                    if now >= nextPulse && self.expected == nil {
                        nextPulse = now + spacing
                        self.sendPulse()
                    }
                } else {
                    let seconds = Int(ceil(startAt - now))
                    if self.remaining != seconds { self.remaining = seconds }
                }
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            }
        }
    }

    func stop() {
        guard activity != .idle else { return }
        if activity == .testing && !sessionReady {
            disconnect()
            message = "Test canceled."
        } else {
            finish("Stopped. A pulse already sent can finish.")
        }
    }

    private func sendPulse() {
        guard let peripheral, let command, sessionReady, expected == nil else { return }
        sequence &+= 1
        expected = .pulse(sequence)
        record("Sent pulse \(sequence)")
        peripheral.writeValue(Puffin.buzz(sequence: sequence), for: command, type: .withResponse)
        startTimeout(seconds: 2, message: "No final vibration response from WHOOP.")
    }

    private func startTimeout(seconds: Int, message: String) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            self?.fail(message)
        }
    }

    private func finish(_ result: String) {
        clockTask?.cancel()
        timeoutTask?.cancel()
        clockTask = nil
        timeoutTask = nil
        expected = nil
        remaining = 0
        activity = .idle
        message = result
    }

    private func clearLink() {
        peripheral?.delegate = nil
        finish("")
        peripheral = nil
        command = nil
        response = nil
        responses = HapticResponses()
        sessionReady = false
        sequence = 1
        connecting = false
        connected = false
        testAcknowledged = false
        confirmed = false
    }

    private func fail(_ reason: String) {
        disconnect()
        message = reason
        record(reason)
    }

    private func record(_ text: String) {
        log.append(text)
        if log.count > 80 { log.removeFirst(log.count - 80) }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            refresh()
        } else {
            clearLink()
            devices = []
            status = "Bluetooth unavailable"
            message = "Check Bluetooth and allow this app to use it in iPhone Settings."
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral == self.peripheral else { return }
        peripheral.discoverServices([serviceID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        fail(error?.localizedDescription ?? "WHOOP connection failed.")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral == self.peripheral else { return }
        fail("WHOOP disconnected. Timer stopped.")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral == self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceID }) else {
            fail("WHOOP 5.0 service unavailable.")
            return
        }
        peripheral.discoverCharacteristics([writeID, responseID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral == self.peripheral, service.uuid == serviceID else { return }
        guard error == nil,
              let command = service.characteristics?.first(where: {
                  $0.uuid == writeID && $0.properties.contains(.write)
              }),
              let response = service.characteristics?.first(where: {
                  $0.uuid == responseID && !$0.properties.intersection([.notify, .indicate]).isEmpty
              }) else {
            fail("Expected WHOOP vibration characteristics were not found.")
            return
        }
        self.command = command
        self.response = response
        timeoutTask?.cancel()
        connecting = false
        connected = true
        status = peripheral.name ?? "WHOOP 5.0"
        message = "Connected. Test one pulse to enable the timer."
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == writeID, let expected else { return }
        if let error {
            fail("WHOOP write failed. \(error.localizedDescription)")
            return
        }
        guard expected == .hello, let response else { return }
        self.expected = .subscription
        peripheral.setNotifyValue(true, for: response)
        startTimeout(seconds: 5, message: "Couldn’t subscribe to WHOOP command replies.")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == responseID, expected == .subscription else { return }
        guard error == nil, characteristic.isNotifying else {
            fail("Couldn’t subscribe to WHOOP command replies.")
            return
        }
        expected = nil
        sessionReady = true
        sendPulse()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral == self.peripheral, characteristic.uuid == responseID else { return }
        if let error, expected != nil {
            fail(error.localizedDescription)
            return
        }
        guard let bytes = characteristic.value else { return }
        for reply in responses.append(bytes) {
            guard expected == .pulse(reply.sequence) else { continue }
            record("Pulse \(reply.sequence) reply \(reply.status)")
            if reply.status == 2 { continue }
            guard reply.status == 1 else {
                fail("WHOOP rejected the pulse (status \(reply.status)).")
                return
            }
            timeoutTask?.cancel()
            expected = nil
            if activity == .testing {
                testAcknowledged = true
                finish("WHOOP acknowledged the pulse.")
            }
        }
    }
}
