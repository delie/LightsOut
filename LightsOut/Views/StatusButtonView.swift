import SwiftUI

struct StatusButton: View {
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var errorHandler: ErrorHandler
    
    @State private var isAnimating = false
    private var statusText: String {
        switch display.state {
        case .mirrored:
            return "Turn On"
        case .disconnected:
            return "Turn On"
        case .active:
            return "Turn Off"
        case .pending:
            return "Pending"
        }
    }

    var body: some View {
        Group {
            if display.state == .active {
                actionButton
                    .buttonStyle(.bordered)
            } else {
                actionButton
                    .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.small)
        .disabled(display.state == .pending)
        .onAppear {
            guard display.state == .pending else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
    }

    private var actionButton: some View {
        Button(action: handlePress) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.caption)

                Text(statusText)
                    .font(.system(size: 12))
            }
        }
    }

    private var statusIcon: String {
        switch display.state {
        case .mirrored:
            return "power"
        case .disconnected:
            return "power"
        case .active:
            return "display.slash"
        case .pending:
            return isAnimating ? "ellipsis.circle.fill" : "ellipsis.circle"
        }
    }

    private func handlePress() {
        if display.state == .pending { return }

        let shiftPressed = NSEvent.modifierFlags.contains(.shift)

        if shiftPressed {
            handleShiftTap()
        } else {
            handleTap()
        }
    }

    private func handleTap() {
        do {
            if display.state.isOff() {
                try viewModel.turnOnDisplay(display: display)
            } else {
                try viewModel.disconnectDisplay(display: display)
            }
        } catch let error {
            errorHandler.handle(error: error)
        }
    }

    private func handleShiftTap() {
        do {
            if display.state.isOff() {
                try viewModel.turnOnDisplay(display: display)
            } else {
                try viewModel.disableDisplay(display: display)
            }
        } catch let error {
            errorHandler.handle(error: error)
        }
    }
}
