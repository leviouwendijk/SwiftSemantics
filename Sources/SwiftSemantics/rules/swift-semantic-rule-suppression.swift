import Foundation

public enum SwiftSemanticRuleSuppression:
    String,
    Sendable,
    Codable,
    Hashable
{
    case forbidden
    case source_directive
}

struct RuleSuppressionIndex:
    Sendable
{
    private struct Directive:
        Sendable
    {
        enum Action:
            Sendable
        {
            case disable
            case enable
            case disable_next_line
        }

        let action: Action
        let ruleIDs: Set<SwiftSemanticRuleID>
        let line: Int
    }

    private let directives: [Directive]

    init(
        source: SwiftSemanticSource
    ) {
        directives = Self.directives(
            in: source.text
        )
    }

    func suppresses(
        _ diagnostic: SwiftSemanticRuleDiagnostic
    ) -> Bool {
        guard let line = diagnostic.lineRange?.start else {
            return false
        }

        var disabled = false
        var disabledForLine = false

        for directive in directives {
            guard directive.line <= line else {
                break
            }

            guard directive.ruleIDs.contains(
                diagnostic.ruleID
            ) else {
                continue
            }

            switch directive.action {
            case .disable:
                disabled = true

            case .enable:
                disabled = false

            case .disable_next_line:
                if directive.line + 1 == line {
                    disabledForLine = true
                }
            }
        }

        return disabled || disabledForLine
    }
}

private extension RuleSuppressionIndex {
    private static func directives(
        in source: String
    ) -> [Directive] {
        source
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .enumerated()
            .compactMap { offset, sourceLine in
                directive(
                    in: String(sourceLine),
                    line: offset + 1
                )
            }
    }

    private static func directive(
        in sourceLine: String,
        line: Int
    ) -> Directive? {
        let trimmed = sourceLine.trimmingCharacters(
            in: .whitespaces
        )

        guard trimmed.hasPrefix("//") else {
            return nil
        }

        let comment = String(
            trimmed.dropFirst(2)
        )
        .trimmingCharacters(
            in: .whitespaces
        )

        let prefix = "swift-semantic:"

        guard comment.hasPrefix(prefix) else {
            return nil
        }

        let payload = String(
            comment.dropFirst(prefix.count)
        )
        .trimmingCharacters(
            in: .whitespaces
        )

        let components = payload.split(
            whereSeparator: \.isWhitespace
        )

        guard let command = components.first else {
            return nil
        }

        let ruleIDs = Set(
            components
                .dropFirst()
                .flatMap { component in
                    component.split(
                        separator: ","
                    )
                }
                .map { component in
                    SwiftSemanticRuleID(
                        rawValue: String(component)
                    )
                }
        )

        guard !ruleIDs.isEmpty else {
            return nil
        }

        let action: Directive.Action

        switch command {
        case "disable":
            action = .disable

        case "enable":
            action = .enable

        case "disable-next-line":
            action = .disable_next_line

        default:
            return nil
        }

        return .init(
            action: action,
            ruleIDs: ruleIDs,
            line: line
        )
    }
}
