import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: StudioModel

    var body: some View {
        Form {
            Section("Export") {
                folderRow(title: "Print folder", url: model.exportFolder, action: model.chooseExportFolder)

                HStack {
                    Text("JPEG quality")
                    Slider(value: $model.jpegQuality, in: 0.85...1, step: 0.01) {
                        Text("JPEG quality")
                    } onEditingChanged: { editing in
                        if !editing { model.saveQuality() }
                    }
                    Text("\(Int(model.jpegQuality * 100))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("Photo Folder") {
                Toggle("Refresh when new photos arrive", isOn: Binding(
                    get: { model.watchEnabled },
                    set: model.setWatchEnabled
                ))
                folderRow(
                    title: "Opened folder",
                    url: model.watchFolder,
                    action: model.chooseWatchFolder
                )

                HStack {
                    Text("Photo browser position")
                    Spacer()
                    Picker("Photo browser position", selection: Binding(
                        get: { model.photoBrowserPosition },
                        set: model.setPhotoBrowserPosition
                    )) {
                        ForEach(PhotoBrowserPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Text("Photos in this folder appear in the thumbnail browser. New files are added without changing or deleting the originals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Original photos are never changed or deleted. Page dimensions and resolution remain locked for event safety; the border and branding can be toggled in the inspector.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(10)
    }

    private func folderRow(title: String, url: URL?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(url?.path(percentEncoded: false) ?? "Not selected")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 290, alignment: .trailing)
            Button("Choose…", action: action)
        }
    }
}
