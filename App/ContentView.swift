import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("接管的工作副本")
                    .font(.headline)

                List(model.configuration.watchedDirectories, id: \.self, selection: $model.selectedDirectory) {
                    path in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .fontWeight(.medium)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(path)
                    .contextMenu {
                        Button("在 Finder 中显示") {
                            model.selectedDirectory = path
                            model.revealSelectedDirectory()
                        }
                    }
                }

                HStack {
                    Button {
                        model.addDirectory()
                    } label: {
                        Label("添加", systemImage: "plus")
                    }

                    Button {
                        model.removeSelectedDirectory()
                    } label: {
                        Label("移除", systemImage: "minus")
                    }
                    .disabled(model.selectedDirectory == nil)

                    Spacer()

                    Button("在 Finder 中显示") {
                        model.revealSelectedDirectory()
                    }
                    .disabled(model.selectedDirectory == nil)
                }
            }
            .padding()
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("命令输出")
                        .font(.headline)
                    if model.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ScrollView {
                    Text(model.output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("在 Finder 中右键接管目录内的文件或文件夹，选择“SVN Finder”。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(minWidth: 380)
        }
    }
}
