import Expression;
import neko.Lib;

class Lua {
    public static function translateToLua(expression: Expression): String {
        var translator = new Lua();
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
                        result += "__call = ";
                        var patterns = lambda[0].patterns.length;
                        for(i in 0...patterns) {
                            if(i != 0) result += "return ";
                            result += "function(S_" + i + ") ";
                        }
                        for(choice in lambda) {
                            var conditions = [];
                            var extractors = [];
                            for(i in 0...patterns) {
                                var translated = translatePattern("S_" + i, choice.patterns[i]);
                                conditions.push(translated.condition);
                                extractors.push(translated.extractor);
                            }
                            result += "if " + conditions.join(" and ") + " then ";
                            result += extractors.join("") + "\n";
                            result += "return " + translate(choice.body) + ";\nelse";
                            result += " error(\"None of the patterns matched.\") end";
                        }
                        for(i in 0...patterns) {
                            result += " end";
                        }
                        result += ",\n";
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
    
    private function translatePattern(getter: String, pattern: Pattern): {condition: String, extractor: String} {
        switch(pattern) {
            case PWildcard:
                return {
                    condition: "true",
                    extractor: "",
                };
            case PVariable(name):
                return {
                    condition: "true",
                    extractor: "local V_" + name + " = " + getter + "; ",
                };
            case PString(value):
                return {
                    condition: getter + " == \"" + escape(value) + "\"",
                    extractor: "",
                };
            case PFloat(value):
                return {
                    condition: getter + " == " + value,
                    extractor: "",
                };
            case PObject(fields):
                var conditions = [];
                var extractors = [];
                for(field in fields) {
                    var result = translatePattern(getter + "[\"F_get" + escape(field.name) + "\"]()", field.pattern);
                    conditions.push(result.condition);
                    extractors.push(result.extractor);
                }
                return {
                    condition: conditions.join(" and "),
                    extractor: extractors.join(""),
                };
            case PVariant(tag, patterns):
                var conditions = [];
                var extractors = [];
                var i = 0;
                for(pattern in patterns) {
                    var result = translatePattern(getter + ".S_" + i, pattern);
                    conditions.push(result.condition);
                    extractors.push(result.extractor);
                    i += 1;
                }
                return {
                    condition: getter + ".S_tag == \"" + tag + "\" and " + conditions.join(" and "),
                    extractor: extractors.join(""),
                };
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
        /*var e3 = EImport(["standard"], "standard", null,
            EApply(EField(EVariable("standard"), "print"), EString("Hello, World!")));
        Lib.println(translateToLua(e3));*/
        var lambda2 = [{
            patterns: [PObject([{name: "P", pattern: PVariable("p")}, {name: "Q", pattern: PVariable("q")}]), PString("foo")],
            body: EVariable("q")
        }];
        var e4 = ELet("f", false, EObject(null, lambda2, new Hash()), EVariable("f"));
        Lib.println(translateToLua(e4));
    }
}

