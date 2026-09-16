import Primitives

public extension SwiftSemanticRules.API.Topology {
    struct ExcessiveSymbolComponents:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.excessiveSymbolComponents
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let maximum = Int(
                context.configuration.maximumSymbolComponents
            )

            return RuleNamedDeclarations.collect(
                in: source
            ).compactMap { declaration in
                let components = Case.components(
                    declaration.name
                )

                guard components.count > maximum else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Symbol '\(declaration.name)' contains \(components.count) lexical components; the configured maximum is \(maximum). Consider nesting shared context, splitting responsibilities, or shortening the symbol.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct SharedSymbolPrefixFamily:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.sharedSymbolPrefixFamily
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let minimum = Int(
                context.configuration.sharedPrefixFamilySize
            )
            let declarations = RuleNamedDeclarations.collect(
                in: source
            ).filter { declaration in
                declaration.isTopLevel
                    && RuleNamedDeclarations.isNominal(
                        declaration.kind
                    )
            }
            var families: [String: [RuleNamedDeclaration]] = [:]

            for declaration in declarations {
                let components = Case.components(
                    declaration.name
                )

                guard components.count >= 3 else {
                    continue
                }

                let prefix = components
                    .prefix(2)
                    .joined(
                        separator: " "
                    )

                families[prefix, default: []].append(
                    declaration
                )
            }

            return families
                .filter { _, members in
                    members.count >= minimum
                }
                .compactMap { prefix, members in
                    guard let first = members.sorted(
                        by: { lhs, rhs in
                            (lhs.lineRange?.start ?? Int.max)
                                < (rhs.lineRange?.start ?? Int.max)
                        }
                    ).first else {
                        return nil
                    }

                    return .init(
                        ruleID: id,
                        severity: .hint,
                        message: "\(members.count) top-level types repeat the lexical prefix '\(prefix)'. Consider a shared namespace or nesting owner instead of serializing scope into every symbol name.",
                        file: source.file,
                        lineRange: first.lineRange
                    )
                }
        }
    }

    struct RedundantNestedTypePrefix:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.redundantNestedTypePrefix
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            _ = context

            return RuleNamedDeclarations.collect(
                in: source
            ).compactMap { declaration in
                guard RuleNamedDeclarations.isNominal(
                    declaration.kind
                ),
                let parent = declaration.parentName else {
                    return nil
                }

                let parentComponents = Case.components(
                    parent
                )
                let childComponents = Case.components(
                    declaration.name
                )

                guard !parentComponents.isEmpty,
                      childComponents.count > parentComponents.count,
                      childComponents.starts(
                        with: parentComponents
                      ) else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Nested type '\(declaration.name)' repeats its enclosing type '\(parent)'. Prefer the enclosing scope to carry that context.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }

    struct ExcessiveTypeNesting:
        SwiftSemanticRule
    {
        public let id = SwiftSemanticRuleID.excessiveTypeNesting
        public let suppression: SwiftSemanticRuleSuppression = .source_directive

        public init() {}

        public func diagnostics(
            in source: SwiftSemanticSource,
            context: SwiftSemanticRuleContext
        ) async throws -> [SwiftSemanticRuleDiagnostic] {
            let maximum = Int(
                context.configuration.maximumNestingLineage
            )

            return RuleNamedDeclarations.collect(
                in: source
            ).compactMap { declaration in
                guard RuleNamedDeclarations.isNominal(
                    declaration.kind
                ),
                declaration.lineage.count > maximum else {
                    return nil
                }

                return .init(
                    ruleID: id,
                    severity: .warning,
                    message: "Type lineage '\(declaration.lineage.joined(separator: "."))' is \(declaration.lineage.count) levels deep; the configured maximum is \(maximum). Consider flattening or splitting the hierarchy.",
                    file: source.file,
                    lineRange: declaration.lineRange
                )
            }
        }
    }
}
