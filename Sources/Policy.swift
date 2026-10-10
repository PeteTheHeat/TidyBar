import Foundation

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case shown, hidden, alwaysHidden
    var id: String { rawValue }
    var title: String {
        switch self { case .shown: return "Always Show"; case .hidden: return "Show on Demand"; case .alwaysHidden: return "Always Hidden" }
    }
    var symbol: String {
        switch self { case .shown: return "eye"; case .hidden: return "eye.slash"; case .alwaysHidden: return "eye.slash.fill" }
    }
    var detail: String {
        switch self {
        case .shown: return "These items stay in your menu bar. New items start here."
        case .hidden: return "Click TidyBar or press ⌥⌘B to show these items."
        case .alwaysHidden: return "These stay hidden, even when you show items on demand."
        }
    }
}

struct VisibilityPolicy {
    let systemItems: [Int]
    let bundles: [String]
    static func make(assignments: [String: ItemCategory], runningBundles: [String], ownBundle: String, revealed: Bool) -> Self {
        func visible(_ category: ItemCategory) -> Bool {
            category == .shown || (category == .hidden && revealed)
        }
        // Unknown and newly launched apps always remain visible.
        let bundles = Set(runningBundles + [ownBundle]).filter {
            $0 == ownBundle || visible(assignments["app:" + $0] ?? .shown)
        }.sorted()
        let system = (0...8).filter { visible(assignments["system:\($0)"] ?? .shown) }
        return .init(systemItems: system, bundles: bundles)
    }
}

func policyTests() -> [String] {
    let rules: [String: ItemCategory] = ["app:shown": .shown, "app:hidden": .hidden, "app:never": .alwaysHidden, "system:6": .hidden, "system:1": .alwaysHidden]
    let closed = VisibilityPolicy.make(assignments: rules, runningBundles: ["shown", "hidden", "never", "new", "self"], ownBundle: "self", revealed: false)
    let open = VisibilityPolicy.make(assignments: rules, runningBundles: ["shown", "hidden", "never", "new", "self"], ownBundle: "self", revealed: true)
    var failures: [String] = []
    if closed.bundles != ["new", "self", "shown"] { failures.append("Collapsed bundle policy") }
    if open.bundles != ["hidden", "new", "self", "shown"] { failures.append("Revealed bundle policy") }
    if closed.systemItems.contains(6) || closed.systemItems.contains(1) { failures.append("Collapsed system policy") }
    if !open.systemItems.contains(6) || open.systemItems.contains(1) { failures.append("Revealed system policy") }
    let relaunch = try? JSONDecoder().decode([String: ItemCategory].self, from: JSONEncoder().encode(rules))
    if relaunch != rules { failures.append("Persistence round trip") }
    let safety = VisibilityPolicy.make(assignments: ["app:self": .alwaysHidden], runningBundles: [], ownBundle: "self", revealed: false)
    if !safety.bundles.contains("self") { failures.append("Recovery control remains visible") }
    return failures
}
