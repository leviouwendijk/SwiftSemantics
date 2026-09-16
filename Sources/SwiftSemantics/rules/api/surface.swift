public extension SwiftSemanticRules.API.Surface {
    struct PublicTupleReturn:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.publicTupleReturn
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            return RuleAPISurface.declarations(
                in: source
            ).compactMap { declaration in
                guard declaration.hasTupleSurface else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Public or package API exposes a multi-element tuple. Prefer a semantic result/value type, nested under its owning API when appropriate.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct PublicAnyType:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.publicAnyType
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            return RuleAPISurface.declarations(
                in: source
            ).compactMap { declaration in
                guard declaration.hasAnySurface else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Public or package API exposes Any or AnyObject. Preserve semantic type information at the API boundary.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct PrimitiveParameterCluster:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.primitiveParameterCluster
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let minimum = Int(
                context.configuration.primitiveParameterClusterSize
            )

            return RuleAPISurface.declarations(
                in: source
            ).compactMap { declaration in
                var counts: [String: Int] = [:]

                for type in declaration.parameterTypes
                    where RuleAPISurface.primitiveTypes.contains(type) {
                    counts[type, default: 0] += 1
                }

                guard let cluster = counts
                    .filter({ _, count in
                        count >= minimum
                    })
                    .max(by: { lhs, rhs in
                        lhs.value < rhs.value
                    }) else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Public or package callable accepts \(cluster.value) '\(cluster.key)' parameters. Consider introducing a semantic value or options type.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct BooleanParameterCluster:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.booleanParameterCluster
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let minimum = Int(
                context.configuration.booleanParameterClusterSize
            )

            return RuleAPISurface.declarations(
                in: source
            ).compactMap { declaration in
                let count = declaration.parameterTypes.count { type in
                    type == "Bool"
                }

                guard count >= minimum else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Public or package callable accepts \(count) Boolean parameters. Prefer named semantic modes, policies, or options when independent flags accumulate.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct ExcessiveParameterCount:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.excessiveParameterCount
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let maximum = Int(
                context.configuration.maximumParameterCount
            )

            return RuleAPISurface.declarations(
                in: source
            ).compactMap { declaration in
                let count = declaration.parameterTypes.count

                guard count > maximum else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .hint,
                    message: "Public or package callable has \(count) parameters; the configured maximum is \(maximum). Consider grouping a coherent subset into a semantic value, policy, or configuration type.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }
}
