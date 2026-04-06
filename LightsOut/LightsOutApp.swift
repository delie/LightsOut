import SwiftUI
import AppKit

@main
struct LightsOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?
    let displaysViewModel = DisplaysViewModel()
    var contextMenuManager: ContextMenuManager!
    var popoverDisplayID: CGDirectDisplayID?
    var savedPopoverOffset: NSPoint?  // position relative to the popover's screen origin
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        popover = NSPopover()
        popover.behavior = .applicationDefined

        displaysViewModel.recoverDisplaysAfterLaunch()
        
        // Set up the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "LightsOut")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        contextMenuManager = ContextMenuManager(statusItem: statusItem)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }

        displaysViewModel.willChangeDisplays = { [weak self] disablingDisplayIDs in
            guard let self,
                  self.popover.isShown,
                  let popoverWindow = self.popover.contentViewController?.view.window,
                  let screen = popoverWindow.screen else { return }
            let popoverDisplayID = screen.displayID
            if !disablingDisplayIDs.isEmpty && disablingDisplayIDs.contains(popoverDisplayID) {
                // The popover is on a display that's about to be disabled — close it
                self.popover.performClose(nil)
                self.popoverDisplayID = nil
                self.savedPopoverOffset = nil
            } else {
                // Save position relative to the screen origin (screen-local coordinates survive global coordinate shifts)
                self.popoverDisplayID = popoverDisplayID
                let screenOrigin = screen.frame.origin
                self.savedPopoverOffset = NSPoint(
                    x: popoverWindow.frame.origin.x - screenOrigin.x,
                    y: popoverWindow.frame.origin.y - screenOrigin.y
                )
            }
        }

        displaysViewModel.didChangeDisplays = { [weak self] in
            guard let self,
                  self.popover.isShown,
                  self.savedPopoverOffset != nil,
                  self.popoverDisplayID != nil else {
                self?.popoverDisplayID = nil
                self?.savedPopoverOffset = nil
                return
            }
            // Defer restoration so it runs after macOS finishes its own window relocation
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.popover.isShown,
                      let savedOffset = self.savedPopoverOffset,
                      let savedDisplayID = self.popoverDisplayID,
                      let popoverWindow = self.popover.contentViewController?.view.window,
                      let screen = NSScreen.screens.first(where: { $0.displayID == savedDisplayID }) else {
                    self?.popoverDisplayID = nil
                    self?.savedPopoverOffset = nil
                    return
                }
                // Restore position using the screen's (potentially new) origin + saved offset
                var frame = popoverWindow.frame
                frame.origin = NSPoint(
                    x: screen.frame.origin.x + savedOffset.x,
                    y: screen.frame.origin.y + savedOffset.y
                )
                popoverWindow.setFrame(frame, display: false)
                self.popoverDisplayID = nil
                self.savedPopoverOffset = nil
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        displaysViewModel.resetAllDisplays(clearPersistedState: false)
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            contextMenuManager.showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let contentView = MenuBarView()
                .environmentObject(displaysViewModel)
                .withErrorHandling()

            popover.contentViewController = NSHostingController(rootView: contentView)

            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Ensure the app and popover window become active
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                popover.contentViewController?.view.window?.makeFirstResponder(popover.contentViewController?.view)
            }
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
}
