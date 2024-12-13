//
//  AppDelegate.swift
//  InnertiaStopper
//
//  Created by Dominik Thomann (privat) on 13.12.2024.
//

import Cocoa
import Quartz

class AppDelegate: NSObject, NSApplicationDelegate {
    var lastMousePosition: NSPoint?
    var isMouseMoving: Bool = false
    var suppressionTimer: Timer?
    var wheelSuppressionTimer: Timer?
    var isWheelSpinning: Bool = false
    let movementThreshold: CGFloat = 5.0  // Minimum movement to trigger suppression
    var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            print("Accessibility permissions are required for this app to function properly.")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "This app requires Accessibility permissions to control and monitor input events. Please enable them in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.runModal()
        }

        // Start mouse movement monitoring
        monitorMouseMovement()

        // Set up global event tap
        setupGlobalEventTap()
    }

    func monitorMouseMovement() {
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }

            let currentMousePosition = NSEvent.mouseLocation  // Global position
            if let lastPosition = self.lastMousePosition {
                let distance = hypot(currentMousePosition.x - lastPosition.x,
                                     currentMousePosition.y - lastPosition.y)

                if distance > self.movementThreshold {
                    self.isMouseMoving = true
                    print("Mouse is moving!")
                    self.startMouseSuppressionTimer()
                } else {
                    print("Mouse moved, but below threshold (\(distance)).")
                }
            }
            self.lastMousePosition = currentMousePosition
        }
    }

    func startMouseSuppressionTimer() {
        suppressionTimer?.invalidate()  // Cancel any existing timer
        suppressionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.isMouseMoving = false
            print("Mouse stopped moving.")
        }
    }

    func startWheelSuppressionTimer() {
        wheelSuppressionTimer?.invalidate()  // Cancel any existing timer
        wheelSuppressionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.isWheelSpinning = false
            print("Mouse wheel stopped spinning.")
        }
    }

    func setupGlobalEventTap() {
            let mask: CGEventMask = (1 << CGEventType.scrollWheel.rawValue)

            // Pass self as refcon to the callback
            let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    // Retrieve the AppDelegate instance from refcon
                    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

                    // Use the AppDelegate instance for logic
                    if appDelegate.isMouseMoving || appDelegate.isWheelSpinning {
                        print("Scroll event suppressed globally.")
                        appDelegate.startWheelSuppressionTimer()  // Reset wheel suppression timer
                        appDelegate.isWheelSpinning = true
                        return nil  // Discard the event
                    }

                    print("Scroll event allowed.")
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
        // Clean up the event tap
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }
}
