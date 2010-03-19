enum Token {
    KComma;
    KSemicolon;
    KColon;
    KParenthesisBegin;
    KParenthesisEnd;
    KBracketBegin;
    KBracketEnd;
    KCurlyBegin;
    KCurlyEnd;
    KType;
    KDot;
    KBar;
    KAt;
    KAssign;
    KWildcard;
    KString(value: String);
    KFloat(value: Float);
    KOperator(name: String);
    KUpper(name: String);
    KLower(name: String);
}

class Lexer implements Iterator<Token> {
    private var c: Char;
    private var position: Char;
    private var text: Array<Char>;
    private var oldToken: Token;
    private var whitespaceToken: Token;
    
    public function new(input: String) {
        text = toArray(input);
        position = 0;
        c = text[0];
        oldToken = null;
        lexWhitespace();
        whitespaceToken = null;
    }

    public function next(): Token {
        if(whitespaceToken != null) {
            var w = whitespaceToken;
            whitespaceToken = null;
            return w;
        }
        oldToken = lexOne();
        lexWhitespace();
        return oldToken;
    }

    public function hasNext(): Bool {
        return position < text.length || whitespaceToken != null;
    }
    
    private function lexOne(): Token {
        if(c >= 'a' && c <= 'z') {
            var result = c;
            consume();
            while((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
                result += c;
                consume();
            }
            return KLower(result);
        } 
        if(c >= 'A' && c <= 'Z') {
            var result = c;
            consume();
            while((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
                result += c;
                consume();
            }
            return KUpper(result);
        } 
        if(c == '(') {
            consume();
            return KParenthesisBegin;
        }
        if(c == ')') {
            consume();
            return KParenthesisEnd;
        }
        if(c == '[') {
            consume();
            return KBracketBegin;
        }
        if(c == ']') {
            consume();
            return KBracketEnd;
        }
        if(c == '{') {
            consume();
            return KCurlyBegin;
        }
        if(c == '}') {
            consume();
            return KCurlyEnd;
        }
        if(c == ',') {
            consume();
            return KComma;
        }
        if(c == ';') {
            consume();
            return KSemicolon;
        }
        if(c == ':') {
            consume();
            if(c == ':') {
                consume();
                if(c == '=') {
                    consume();
                    return KExport;
                }
                return KType;
            }
            if(c == '=') {
                consume();
                return KDefine;
            }
            return KColon;
        }
        if(c == '_') {
            consume();
            return KWildcard;
        }
        if("+-*/^@$%&=?^.<>\|~".contains(c)) {
            var result = c;
            consume();
            if((result == "-" || result == "+") && c >= '0' && c <= '9') return lexFloat(result);
            while("!+-*/^@$%&=?^.<>\|~".contains(c)) {
                result += c;
                consume();
            }
            if(result == "=") return KAssign;
            if(result == "|") return KBar;
            if(result == ".") return KDot;
            if(result == "@") return KAt;
            return KOperator(result);
        }
        return lexFloat("");
    }
    
    private function lexFloat(result: String): Token {
        if(c >= '0' && c <= '9') {
            var result = c;
            consume();
            while((c >= '0' && c <= '9')) {
                result += c;
                consume();
            }
            var p = position;
            var r = result;
            if(c == '.') {
                result += c;
                consume();
                if(c >= '0' && c <= '9') { 
                    while(c >= '0' && c <= '9') {
                        result += c;
                        consume();
                    }
                } else {
                    result = r;
                    position = p;
                    c = text[position];
                }
            }
            r = result;
            p = position;
            if(c == 'e' || c == 'E') {
                result += c;
                consume();
                if(c == '+' || c == '-') {
                    result += c;
                    consume();
                }
                if(c >= '0' && c <= '9') { 
                    while(c >= '0' && c <= '9') {
                        result += c;
                        consume();
                    }
                } else {
                    result = r;
                    position = p;
                    c = text[position];
                }
            } else {
                position = p;
                c = text[position];
            }
            return KFloat(Std.parseFloat(result));
        }
        throw "Unexpected character '" + c + "' at " + position;
    }

    private function lexString(): Token {
        if(c >= '\'') {
            var result = "";
            consume();
            while(true) {
                if(c == '\'') {
                    consume();
                    if(c != '\'') break;
                }
                result += c;
                consume();
            }
            return KString(result);
        }
        throw "Unexpected character '" + c + "' at " + position;
    }
    
    private inline function lexWhitespace(): Void {
        while(c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            if((c == '\r' || c == '\n') && (oldToken == KUpper || oldToken == KLower || oldToken == KWildcard || 
                    oldToken == KString || oldToken == KFloat ||
                    oldToken == KParenthesisEnd || oldToken == KBracketEnd || oldToken == KCurlyEnd)) {
                whitespaceToken = KSemicolon;
            }
            consume();
        }
    }
    
    private inline function consume(): Char {
        position += 1;
        c = text[position];
    }
}

