/// Namespace for deterministic Swift semantic rules.
///
/// Each nested namespace contributes shared semantic context so concrete rule
/// names remain concise without becoming ambiguous.
public enum SwiftSemanticRules {
    public enum Traps {}
    public enum Enums {}

    public enum API {
        public enum Topology {}
        public enum Surface {}
    }

    public enum Formatting {}
    public enum Source {}
}
