public protocol Greeter {
    func greet() -> String
}

public struct EnglishGreeter: Greeter {
    public init() {}

    public func greet() -> String {
        "hello"
    }
}