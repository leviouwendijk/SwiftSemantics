import Foundation
import SwiftSemantics
import SwiftSyntax

/// Strict SwiftSyntax-driven operations; no source rewriting or filesystem effects.
public struct SwiftRefactoringPlanner: Sendable {
    public init() {}

    /// Plan relocation between unconstrained, non-conforming extensions of
    /// the same syntactically named type. Ambiguous declarations and conflicting
    /// members are rejected. This is a syntax-preserving operation, not proof
    /// of semantic equivalence: compiler verification is required before
    /// publishing the resulting source changes.
    public func moveFunction(
        named name: String,
        inExtensionOf type: String,
        from source: SwiftSemanticSource,
        to destination: SwiftSemanticSource,
        destinationExtensionIndex: Int = 0
    ) throws -> SwiftRefactoringPlan {
        guard let sourceFile = source.file,
            let destinationFile = destination.file else {
            throw SwiftRefactoringError.sourceFileRequired
        }
        guard sourceFile != destinationFile || source.text == destination.text else {
            throw SwiftRefactoringError.inconsistentSnapshots
        }
        guard !source.syntax.hasError, !destination.syntax.hasError else {
            throw SwiftRefactoringError.invalidSyntax(sourceFile)
        }

        let sources = extensions(in: source)
            .filter { $0.extendedType.trimmedDescription == type }
        let matches = sources.flatMap { declaration in
            declaration.memberBlock.members.compactMap { member -> (ExtensionDeclSyntax, MemberBlockItemSyntax)? in
                guard member.decl.as(FunctionDeclSyntax.self)?.name.text == name else {
                    return nil
                }
                return (declaration, member)
            }
        }
        guard !matches.isEmpty else {
            throw SwiftRefactoringError.missingDeclaration
        }
        guard matches.count == 1 else {
            throw SwiftRefactoringError.ambiguousDeclaration
        }

        let targets = extensions(in: destination)
            .filter { $0.extendedType.trimmedDescription == type }
        guard targets.indices.contains(destinationExtensionIndex) else {
            throw SwiftRefactoringError.missingDestination
        }

        let (origin, member) = matches[0]
        let target = targets[destinationExtensionIndex]
        guard origin.inheritanceClause == nil,
            target.inheritanceClause == nil,
            origin.genericWhereClause == nil,
            target.genericWhereClause == nil else {
            throw SwiftRefactoringError.conditionalOrConformingExtension
        }
        guard sourceFile != destinationFile || origin.position != target.position else {
            throw SwiftRefactoringError.sameContainer
        }
        guard !target.memberBlock.members.contains(where: {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == name
        }) else {
            throw SwiftRefactoringError.conflictingMember
        }
        if sourceFile != destinationFile,
            let function = member.decl.as(FunctionDeclSyntax.self),
            function.modifiers.contains(where: {
                $0.name.text == "private" || $0.name.text == "fileprivate"
            }) {
            throw SwiftRefactoringError.fileScopedAccess
        }

        let range = member.position.utf8Offset..<member.endPosition.utf8Offset
        let data = Data(source.text.utf8)
        guard range.lowerBound >= 0,
            range.upperBound <= data.count,
            let captured = String(
                data: data.subdata(in: range),
                encoding: .utf8
            ) else {
            throw SwiftRefactoringError.invalidEdit(sourceFile)
        }
        let insertion = target.memberBlock.rightBrace.position.utf8Offset
        let insertionText = captured.hasSuffix("\n") ? captured : captured + "\n"
        let declaration = SwiftRefactoringDeclaration(
            file: sourceFile,
            name: name,
            extendedType: type,
            utf8Range: range,
            text: captured
        )
        let edits = [
            SwiftRefactoringEdit(
                file: sourceFile,
                utf8Range: range,
                expected: captured,
                replacement: ""
            ),
            SwiftRefactoringEdit(
                file: destinationFile,
                utf8Range: insertion..<insertion,
                expected: "",
                replacement: insertionText
            ),
        ]
        var baselines = [sourceFile: source.text]
        baselines[destinationFile] = destination.text

        let plan = SwiftRefactoringPlan(
            declaration: declaration,
            destination: destinationFile,
            edits: edits,
            baselines: baselines
        )
        for (file, text) in try plan.preview(sources: baselines) {
            guard !SwiftSemanticSource(source: text).syntax.hasError else {
                throw SwiftRefactoringError.invalidSyntax(file)
            }
        }
        return plan
    }

    private func extensions(in source: SwiftSemanticSource) -> [ExtensionDeclSyntax] {
        let collector = ExtensionCollector(viewMode: .sourceAccurate)
        collector.walk(source.syntax)
        return collector.declarations
    }
}

private final class ExtensionCollector: SyntaxVisitor {
    var declarations: [ExtensionDeclSyntax] = []

    override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        declarations.append(node)
        return .skipChildren
    }
}
