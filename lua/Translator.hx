import neko.Lib;

enum Pattern {
    PWildcard;
    PVariable(name: String);
    //PObject(fields: Array<{name: String, pattern: Pattern}>);
}

enum Expression {
    EImport(module: Array<String>, name: Null<String>, names: Array<{target: String, source: String}>, body: Expression);
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

class Translator {
    public static function translateToLua(expression: Expression): String {
        var translator = new Translator();
        var body = translator.translate(expression);
        var prelude = "local function S_string(s) local S_self = nil; S_self = {S_value = s, F_toString = function() return S_self end}; return S_self end; ";
        prelude += "local function S_float(s) return {S_value = s, F_toString = function() return S_string(\"\"..s) end} end; ";
        for(name in translator.imports.keys()) {
            prelude += "local " + name + " = require(\"" + escape(name) + "\"); ";
        }
        prelude += "local S_module = {}; ";
        prelude += "local S_ignore = " + body + "; ";
        prelude += "\nreturn S_module";
        return prelude;
    }

    private var imports: Hash<Array<String>>;

    public function new() {
        this.imports = new Hash();
    }

    private function translate(expression: Expression): String {
        switch(expression) {
            case EImport(module, name, names, body):
                imports.set(moduleName(module), module);
                var result = "((function() ";
                if(name != null) {
                    result += "local V_" + name + " = " + moduleName(module) + "; ";
                }
                if(names != null) {
                    for(name in names) {
                        result += "local V_" + name.target + " = " + moduleName(module) + ".F_" + name.source + "; ";
                    }
                }
                return result + "return " + translate(body) + " end) ())";
            case ELet(name, export, value, body):
                var result = "((function() ";
                result += "local V_" + name + " = " + translate(value) + ";\n";
                if(export) {
                    result += "S_module.F_" + name + " = V_" + name + ";\n";
                }
                return result + "return " + translate(body) + " end) ())";
            case ERecursive(definitions, body):
                var result = "((function() ";
                for(definition in definitions) {
                    result += "local V_" + definition.name + " = nil; ";
                }
                for(definition in definitions) {
                    result += "V_" + definition.name + " = " + translate(definition.value) + ";\n";
                    if(definition.export) {
                        result += "S_module.F_" + definition.name + " = V_" + definition.name + ";\n";
                    }
                }
                return result + "return " + translate(body) + " end) ())";
            case EVariable(name):
                return "V_" + name;
            case EAssign(name, value):
                return "((function() " + name + " = " + translate(value) + " end) ())";
            case ESequence(left, right):
                return "((function() local S_ignore = " + translate(left) + ";\nreturn " + translate(right) + " end) ())";
            case EApply(target, argument):
                return "(" + translate(target) + "(" + translate(argument) + ")" + ")";
            case EField(target, name):
                return "(" + translate(target) + "[\"F_" + escape(name) + "\"])";
            case EObject(parent, lambda, fields):
                var result = "((function() local S_object = {";
                for(name in fields.keys()) {
                    result += "[\"F_" + escape(name) + "\"] = " + translate(fields.get(name)) + ",\n";
                }
                if(lambda != null) {
                    var done = false;
                    if(lambda.length == 1 && lambda[0].patterns.length == 1) {
                        switch(lambda[0].patterns[0]) {
                            case PVariable(name): 
                                result += "__call = function(V_" + name + ") return " + translate(lambda[0].body) + " end,\n";
                                done = true;
                            case PWildcard: 
                                result += "__call = function() return " + translate(lambda[0].body) + " end,\n";
                                done = true;
                            default:
                        }
                    }
                    if(!done) {
                        throw "Not implemented"; // TODO
                        /*
                        result += "__call = function(S_parameter)\n";
                        for(choice in lambda) {
                            result += "if " + translateMatcher(choice.pattern, "S_parameter") + " then ";
                            result += translateExtractor(choice.pattern, "S_parameter") + "\n";
                            result += "return " + translate(choice.body) + ";\nelse";
                            result += " error(\"None of the patterns matched.\") end end,\n";
                        }
                        */
                    }
                }
                if(parent != null) {
                    result += "__index = " + translate(parent) + ",\n";
                }
                if(lambda != null || parent != null) {
                    return result + "}; return setmetatable(S_object, S_object) end) ())";
                } else {
                    return result + "}; return S_object end) ())";
                }
            case EString(value):
                return "S_string(\"" + escape(value) + "\")";
            case EFloat(value):
                return "S_float(" + value + ")";
        }
    }
    
    private function translateMatcher(pattern: Pattern, getter: String) {
        switch(pattern) {
            case PWildcard:
                return "true";
            case PVariable(name):
                return "true";
        }
    }

    private function translateExtractor(pattern: Pattern, getter: String) {
        switch(pattern) {
            case PWildcard:
                return "";
            case PVariable(name):
                return "local V_" + name + " = " + getter + "; ";
        }
    }

    private static function moduleName(parts: Array<String>): String {
        var result = "M";
        for(part in parts) {
            result += "_" + part;
        }
        return result;
    }
    
    private static function escape(value: String): String {
        value = StringTools.replace(value, "\\", "\\\\");
        value = StringTools.replace(value, "\"", "\\\"");
        value = StringTools.replace(value, "\r", "\\r");
        value = StringTools.replace(value, "\n", "\\n");
        value = StringTools.replace(value, "\t", "\\t");
        return value;
    }
    
    public static function main() {
        var fields = new Hash();
        fields.set("a", EString("blah"));
        var lambda = [{
            patterns: [PVariable("x")],
            body: EVariable("x")
        }];
        /*var e1 = EImport(["graphics", "opengl"], "gl", [{target: "start", source: "begin"}, {target: "stop", source: "end"}],
            ELet("o", true, EObject(null, lambda, fields), ESequence(EApply(EVariable("o"), EString("baz")), EVariable("o"))));
        Lib.println(translateToLua(e1));*/
        /*var e2 = ERecursive([
            {name: "begin", export: true, value: EString("beginning")},
            {name: "end", export: true, value: EString("ending")},
            ], EString(""));
        Lib.println(translateToLua(e2));*/
        var e3 = EImport(["standard"], "standard", null,
            EApply(EField(EVariable("standard"), "print"), EString("Hello, World!")));
        Lib.println(translateToLua(e3));
    }
}

/*
# Ugly example
@graphics.opengl gl (start := begin, stop := end)
o ::= (:{|x| x},
    a: "blah"
)
o("baz")
o
*/

