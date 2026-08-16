import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        installDockIcon()

        // Re-apply after the first run-loop pass in case LaunchServices updates
        // the Dock tile immediately after the application finishes launching.
        DispatchQueue.main.async { [weak self] in
            self?.installDockIcon()
        }
    }

    private func installDockIcon() {
        guard let iconURL = Bundle.main.url(
            forResource: "CollaroidStudioDockIcon",
            withExtension: "png"
        ), let icon = NSImage(contentsOf: iconURL) else {
            assertionFailure("The Collaroid Studio Dock icon is missing from the app bundle")
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}

@main
struct CollaroidStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = StudioModel()

    var body: some Scene {
        WindowGroup {
            StudioView()
                .environmentObject(model)
                .tint(Color(red: 1.0, green: 0.36, blue: 0.12))
                .frame(minWidth: 900, minHeight: 680)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1180, height: 780)
        .commands {
            StudioCommands(model: model)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .tint(Color(red: 1.0, green: 0.36, blue: 0.12))
                .frame(width: 620, height: 430)
        }
    }
}

struct StudioCommands: Commands {
    @ObservedObject var model: StudioModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Photo…") { model.choosePhoto() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print") { model.printCurrent() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!model.hasPhoto)
        }

        CommandMenu("Photo") {
            Button("Previous Folder Photo") { model.selectPreviousFolderPhoto() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!model.canSelectPreviousFolderPhoto)
            Button("Next Folder Photo") { model.selectNextFolderPhoto() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!model.canSelectNextFolderPhoto)
            Divider()
            Button("Zoom In") { model.zoomIn() }
                .keyboardShortcut("+", modifiers: [])
                .disabled(!model.hasPhoto)
            Button("Zoom Out") { model.zoomOut() }
                .keyboardShortcut("-", modifiers: [])
                .disabled(!model.hasPhoto)
            Button("Reset Crop") { model.resetCrop() }
                .keyboardShortcut("r", modifiers: [])
                .disabled(!model.hasPhoto)
            Divider()
            Button("Export & Next") { model.exportAndNext() }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!model.hasPhoto || model.isWorking)
        }
    }
}
