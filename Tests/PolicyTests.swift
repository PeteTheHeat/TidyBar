import Foundation

@main
struct PolicyTestRunner {
    static func main() {
        let failures = policyTests()
        if failures.isEmpty {
            print("PASS: visibility categories, system controls, new apps, recovery icon, persistence")
        } else {
            failures.forEach { print("FAIL: \($0)") }
            exit(1)
        }
    }
}
