import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var updateService: AppUpdateService
    @State private var isLoading: Bool = false
    @AppStorage("ShowStartupPrompt") private var showStartupPrompt: Bool = true

    var body: some View {
        ZStack {
            ContentView(isLoading: $isLoading)
                .environmentObject(viewModel)
                .environmentObject(updateService)
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1.0)

            if showStartupPrompt {
                CustomUserPrompt(
                    title: "Enable Launch at Login",
                    message: "Would you like this app to launch automatically when you log in?",
                    primaryButton: ("Yes", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = true
                    }),
                    secondaryButton: ("No", {
                        showStartupPrompt = false
                        LaunchAtLogin.isEnabled = false
                    })
                )
            }
        }
        .frame(width: 372)
        .animation(.snappy, value: isLoading)
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var updateService: AppUpdateService
    @Binding var isLoading: Bool
    @State private var isShiftPressed = false

    var body: some View {
        VStack(spacing: 0) {
            MenuBarHeader(isLoading: $isLoading)
                .environmentObject(updateService)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            Divider()

            DisplayListView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            Divider()

            FooterText(isShiftPressed: $isShiftPressed)
                .padding(.top, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

struct FooterText: View {
    @Binding var isShiftPressed: Bool
    @State private var eventMonitor: Any?
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Hold Shift for mirror-based disable.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if isShiftPressed {
                Text("Shift")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: {
                if let url = URL(string: "https://alonx2.github.io/LightsOut/docs/disable-methods.html") {
                    openURL(url)
                }
            }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isShiftPressed = event.modifierFlags.contains(.shift)
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }
}

#Preview("MenuBarView") {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
        .environmentObject(AppUpdateService())
}

#Preview("ContentView") {
    ContentView(isLoading: .constant(false))
        .environmentObject(DisplaysViewModel())
        .environmentObject(AppUpdateService())
        .frame(width: 372)
}

#Preview("FooterText") {
    FooterText(isShiftPressed: .constant(false))
        .padding()
}
