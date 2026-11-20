public protocol Greeter {
    func greet() -> String
}

public struct EnglishGreeter: Greeter {
    public init() {}

    public func greet() -> String {
        "hello"
    }
}

public class Base {}
public final class Derived: Base {}

public func leaf() -> String {
    "leaf"
}

public func caller() -> String {
    leaf()
}