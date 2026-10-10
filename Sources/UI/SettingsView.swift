import SwiftUI

final class SettingsUIState: ObservableObject {
    @Published var selection = 0
    @Published var search = ""
    @Published var dropTarget: ItemCategory?
    @Published var activeItem: String?
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    private let staticRendering: Bool
    @StateObject private var ui: SettingsUIState
    init(model: AppModel, selection: Int = 0, staticRendering: Bool = false) {
        self.model = model
        self.staticRendering = staticRendering
        let state = SettingsUIState()
        state.selection = selection
        _ui = StateObject(wrappedValue: state)
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "line.3.horizontal.decrease.circle.fill", accessibilityDescription: "TidyBar")!)
                        .resizable().scaledToFit().frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TidyBar").font(.title3.bold())
                        Text("A little less clutter.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 28).padding(.top, 16)
                sidebar("Menu Bar Items", symbol: "menubar.rectangle", tag: 0)
                sidebar("Permissions", symbol: "hand.raised", tag: 1)
                Spacer()
                Label("Native to your Mac", systemImage: "apple.logo").font(.caption).foregroundStyle(.secondary)
                Text("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)").font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(2)
            }.padding(20).frame(width: 205).background(.ultraThinMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(ui.selection == 0 ? "Your menu bar. Your rules." : "Permission to tidy up.").font(.system(size: 25, weight: .semibold))
                        Text(ui.selection == 0 ? "Drag items between sections, or use an item’s menu." : "TidyBar uses macOS access to manage your menu bar locally.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if ui.selection == 0 { Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh menu bar items") }
                }.padding(.bottom, 25)
                if ui.selection == 0 { itemsPane } else { permissionsPane }
                Spacer(minLength: 10)
                Divider().padding(.bottom, 12)
                HStack(spacing: 8) {
                    Circle().fill(model.accessibility && model.backendAvailable ? Color.green : Color.orange).frame(width: 6, height: 6)
                    Text(model.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    if model.busy { ProgressView().controlSize(.small) }
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(minWidth: 920, minHeight: 780)
    }
    private func sidebar(_ title: String, symbol: String, tag: Int) -> some View {
        Button { ui.selection = tag } label: {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(ui.selection == tag ? Color.accentColor.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    private var itemsPane: some View {
        VStack(alignment: .leading, spacing: 17) {
            if !model.accessibility {
                HStack {
                    Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                    Text("Allow Accessibility to load your real menu bar items.").font(.callout)
                    Spacer()
                    Button("Grant Access") { model.requestAccessibility() }.buttonStyle(.borderedProminent)
                }.padding(14).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                if staticRendering { Text("Find a menu bar item").foregroundStyle(.secondary) }
                else { TextField("Find a menu bar item", text: $ui.search).textFieldStyle(.plain) }
                Spacer()
                Text("\(model.items.filter(\.manageable).count) items").font(.caption).foregroundStyle(.secondary)
            }.padding(10).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            if staticRendering {
                sections.frame(maxHeight: .infinity, alignment: .top)
            } else { ScrollView { sections } }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Show on demand").font(.callout.weight(.medium))
                    Text("Click the TidyBar icon or press ⌥⌘B anywhere.").font(.caption).foregroundStyle(.secondary)
                    if !model.hotkeyAvailable { Text("Shortcut unavailable — another app is using ⌥⌘B.").font(.caption).foregroundStyle(.orange) }
                }
                Spacer()
                Button(model.revealed ? "Hide Items" : "Show Items") { model.toggle() }
                    .disabled(!model.accessibility || model.paused || !model.backendAvailable)
            }
            Toggle("Hide on-demand items again after 15 seconds", isOn: $model.autoHide).font(.callout)
            Toggle("Pause hiding and show all items", isOn: Binding(get: { model.paused }, set: { model.setPaused($0) })).font(.callout)
            Text("Apple manages some system indicators, including Now Playing and User. Native hiding may temporarily suppress these.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private var sections: some View {
        VStack(spacing: 20) {
            ForEach(ItemCategory.allCases) { category in section(category) }
        }.padding(2)
    }
    private func itemRow(_ items: [BarItem]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in tile(item).frame(width: 76) }
        }
    }
    private func section(_ category: ItemCategory) -> some View {
        let items = model.items.filter { $0.manageable && model.category($0) == category && (ui.search.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.search)) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(category.title, systemImage: category.symbol).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                if items.isEmpty {
                    Text(ui.search.isEmpty ? "Drop items here" : "No matching items").font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    if staticRendering { itemRow(items).frame(maxWidth: .infinity, alignment: .leading) }
                    else { ScrollView(.horizontal) { itemRow(items) }.scrollIndicators(.hidden) }
                }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 84)
                .background(ui.dropTarget == category ? Color.accentColor.opacity(0.22) : Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(ui.dropTarget == category ? 0.8 : 0.2)))
                .transformIf(!staticRendering) { tray in
                    tray.dropDestination(for: String.self) { identifiers, _ in
                        recordDrag("drop \(category.rawValue) \(identifiers)")
                        guard let id = identifiers.first, let item = model.items.first(where: { $0.id == id }) else { return false }
                        model.assign(item, to: category)
                        return true
                    } isTargeted: { targeted in
                        recordDrag("target \(category.rawValue) \(targeted)")
                        ui.dropTarget = targeted ? category : nil
                    }
                }
            Text(category.detail).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func tile(_ item: BarItem) -> some View {
        VStack(spacing: 7) {
                Group {
                    if let icon = item.icon { Image(nsImage: icon).resizable().scaledToFit() }
                    else { Image(systemName: item.systemID.map { MenuBarScanner.systemSymbols[$0] } ?? "app.dashed").resizable().scaledToFit() }
                }.frame(width: 27, height: 27)
                Text(item.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                if !item.available { Text("Not running").font(.system(size: 9)).foregroundStyle(.secondary) }
                else if !item.manageable { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity).frame(height: 70).background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
                .opacity(item.available ? 1 : 0.5)
            .contentShape(Rectangle())
            .overlay {
                if !staticRendering { NativeDragHandle(identifier: item.id, icon: item.icon) { ui.activeItem = item.id } }
            }
            .help("\(item.name) · \(item.bundleID)\nmacOS manages icons from the same app together.")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.name + (item.available ? "" : ", not running"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { ui.activeItem = item.id }
            .popover(isPresented: Binding(get: { ui.activeItem == item.id }, set: { if !$0 { ui.activeItem = nil } })) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name).font(.headline)
                    ForEach(ItemCategory.allCases) { category in
                        Button {
                            model.assign(item, to: category)
                            ui.activeItem = nil
                        } label: {
                            Label(category.title, systemImage: model.category(item) == category ? "checkmark" : category.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.disabled(!item.manageable)
                    }
                }.padding(16).frame(width: 210)
            }
    }
    private var permissionsPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            permission("Accessibility", subtitle: "Identifies the apps and system items in your menu bar.", symbol: "accessibility", granted: model.accessibility, action: model.requestAccessibility)
            permission("Screen Recording", subtitle: "Optional. Shows actual menu bar icon previews instead of app icons.", symbol: "rectangle.inset.filled", granted: model.screenRecording, action: model.requestScreenRecording)
            HStack(spacing: 14) {
                Image(systemName: "menubar.rectangle").font(.title2).frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Menu Bar Control").font(.headline)
                    Text("Native macOS 27 support. Access is checked when you hide an item.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(model.backendAvailable ? "Available" : "Unavailable", systemImage: model.backendAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(model.backendAvailable ? .green : .orange).font(.callout)
            }.padding(18).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            Text("Permissions stay under your control in System Settings → Privacy & Security. TidyBar stores your choices on this Mac. Items from the same app are managed together by macOS.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("If a macOS update changes menu bar support, TidyBar restores the bar and shows an error. Quitting always restores hidden items.").font(.caption).foregroundStyle(.secondary)
            Button("Open Accessibility Settings") { model.openPrivacy("Privacy_Accessibility") }
        }
    }
    private func permission(_ title: String, subtitle: String, symbol: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted { Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout) }
            else { Button("Grant Access", action: action) }
        }.padding(18).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    @ViewBuilder func transformIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
