typedef Type = Void;

enum Pattern {
    PWildcard;
    PVariable(name: String);
    PString(value: String);
    PFloat(value: Float);
    PObject(fields: Array<{name: String, pattern: Pattern}>);
    PVariant(tag: String, patterns: Array<Pattern>);
}

enum Expression {
    EImport(module: Array<String>, name: Null<String>, names: Array<{target: String, source: String}>, body: Expression);
    EDefineVariant(name: String, export: Bool, constructors: Array<{name: String, parameters: Array<Type>}>, body: Expression);
    ELet(name: String, export: Bool, value: Expression, body: Expression);
    ERecursive(definitions: Array<{name: String, export: Bool, value: Expression}>, body: Expression);
    EVariable(name: String);
    ESequence(left: Expression, right: Expression);
    EAssign(name: String, value: Expression);
    EApply(target: Expression, argument: Expression);
    EField(target: Expression, name: String);
    EObject(parent: Null<Expression>, lambda: Null<Array<{patterns: Array<Pattern>, body: Expression}>>, fields: Hash<Expression>);
    EString(value: String);
    EFloat(value: Float);
}

