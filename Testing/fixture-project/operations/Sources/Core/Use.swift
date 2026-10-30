public func makeGreeting() -> String {
    let greeter = EnglishGreeter()
    return greeter.greet()
}

public let broken: String = 1