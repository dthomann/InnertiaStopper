import Cocoa
import Quartz

class AppDelegate: NSObject, NSApplicationDelegate {
    var initialMousePosition: NSPoint?      // Mouse position when wheel started
    var isWheelSpinning: Bool = false       // Indicates if the wheel is currently spinning
    var wheelSuppressionTimer: Timer?       // Timer to reset wheel suppression state
    var maxSuppressionFactor: Double = 1.0  // Tracks the highest suppression factor reached

    let movementThreshold: CGFloat = 5.0     // Minimum movement to trigger slowdown
    let maxMovementThreshold: CGFloat = 150.0 // Movement after which scrolling is fully suppressed
    var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Enable Accessibility permissions for this app in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.runModal()
        }

        setupGlobalEventTap()
    }

    func startWheelSuppressionTimer() {
        wheelSuppressionTimer?.invalidate()
        wheelSuppressionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.resetScrollSuppression()
            print("Mouse wheel stopped spinning. Suppression reset.")
        }
    }

    func resetScrollSuppression() {
        isWheelSpinning = false
        maxSuppressionFactor = 1.0  // Reset suppression factor
        initialMousePosition = nil  // Reset initial mouse position
    }

    func setupGlobalEventTap() {
        let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

                // Capture scroll event details
                let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)

                // Handle wheel start
                if !appDelegate.isWheelSpinning {
                    appDelegate.isWheelSpinning = true
                    appDelegate.initialMousePosition = NSEvent.mouseLocation  // Capture initial mouse position
                    print("Wheel started spinning. Initial mouse position: \(String(describing: appDelegate.initialMousePosition))")
                }

                // Calculate total movement relative to the initial position
                guard let initialPosition = appDelegate.initialMousePosition else {
                    return Unmanaged.passUnretained(event)
                }

                let currentMousePosition = NSEvent.mouseLocation
                let distance = hypot(currentMousePosition.x - initialPosition.x,
                                     currentMousePosition.y - initialPosition.y)

                if distance > appDelegate.movementThreshold {
                    if distance >= appDelegate.maxMovementThreshold {
                        // Fully suppress scrolling
                        print("Scroll fully suppressed. Distance: \(distance)")
                        appDelegate.startWheelSuppressionTimer()
                        return nil
                    } else {
                        // Gradually slow down scroll based on the maximum suppression factor
                        let reductionFactor = max(0.0, 1.0 - (distance / appDelegate.maxMovementThreshold))
                        appDelegate.maxSuppressionFactor = min(appDelegate.maxSuppressionFactor, reductionFactor)

                        let adjustedDeltaY = deltaY * appDelegate.maxSuppressionFactor
                        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: adjustedDeltaY)
                        print("Scroll slowed. Distance: \(distance), Reduction Factor: \(appDelegate.maxSuppressionFactor)")
                    }
                }

                // Start suppression timer to detect wheel stop
                appDelegate.startWheelSuppressionTimer()

                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("Event tap successfully set up.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }
}

