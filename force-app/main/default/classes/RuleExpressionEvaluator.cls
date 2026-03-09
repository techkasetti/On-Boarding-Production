public with sharing class RuleExpressionEvaluator {
    public class EvalException extends Exception {}

    public static Boolean evaluate(String expr, Map<String,Object> candidateMap, Map<String,Object> parsedJson) {
        if (String.isBlank(expr)) return false;
        List<Token> tokens = tokenize(expr);
        List<Token> rpn = toRpn(tokens);
        return evaluateRpn(rpn, candidateMap, parsedJson);
    }

    private class Token {
        public String t;
        public String type;
        public Token(String t, String type) { this.t = t; this.type = type; }
        public override String toString() { return '['+type+':'+t+']'; }
    }

    private static List<Token> tokenize(String s) {
        s = s == null ? '' : s.trim();
        List<Token> out = new List<Token>();
        Integer i = 0;
        while (i < s.length()) {
            String ch = s.substring(i, i+1);
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') { i++; continue; }
            if (ch == '(') { out.add(new Token('(', 'LPAR')); i++; continue; }
            if (ch == ')') { out.add(new Token(')', 'RPAR')); i++; continue; }
            if (ch == '\'') {
                Integer j = i+1;
                String buf = '';
                Boolean closed = false;
                while (j < s.length()) {
                    String cj = s.substring(j,j+1);
                    if (cj == '\'') { closed = true; j++; break; }
                    buf += cj; j++;
                }
                if (!closed) throw new EvalException('Unterminated string literal in expr: ' + s);
                out.add(new Token(buf, 'STR'));
                i = j;
                continue;
            }
            if (i+1 < s.length()) {
                String two = s.substring(i, i+2);
                if (two == '>=' || two == '<=' || two == '==' || two == '!=') { out.add(new Token(two, 'OP')); i += 2; continue; }
            }
            if (ch == '>' || ch == '<') { out.add(new Token(ch,'OP')); i++; continue; }
            if (isAlphaNumeric(ch) || ch == '.' || ch == '_') {
                Integer j = i;
                String buf = '';
                while (j < s.length()) {
                    String cj = s.substring(j,j+1);
                    if (isAlphaNumeric(cj) || cj == '.' || cj == '_' ) { buf += cj; j++; } else break;
                }
                if (isNumericLiteral(buf)) { out.add(new Token(buf,'NUM')); }
                else {
                    String up = buf.toUpperCase();
                    if (up == 'AND' || up == 'OR' || up == 'NOT' || up == 'CONTAINS' || up == 'NOT_CONTAINS') {
                        out.add(new Token(up,'OP'));
                    } else {
                        out.add(new Token(buf,'IDENT'));
                    }
                }
                i = j; continue;
            }
            throw new EvalException('Unexpected character in expression: "' + ch + '" at pos ' + i + ' for expr: ' + s);
        }
        return out;
    }

    private static Boolean isAlphaNumeric(String ch) {
        if (String.isBlank(ch)) return false;
        Integer code = (Integer)ch.charAt(0);
        return (code >=48 && code <=57) || (code>=65 && code<=90) || (code>=97 && code<=122);
    }

    private static Boolean isNumericLiteral(String s) {
        if (String.isBlank(s)) return false;
        try { Decimal.valueOf(s); return true; } catch (Exception ex) { return false; }
    }

    private static Integer precedence(String op) {
        op = (op==null) ? '' : op.toUpperCase();
        if (op == 'NOT') return 4;
        if (op == 'CONTAINS' || op == 'NOT_CONTAINS') return 3;
        if (op == '==' || op == '!=' || op == '>' || op == '<' || op == '>=' || op == '<=') return 3;
        if (op == 'AND') return 2;
        if (op == 'OR') return 1;
        return 0;
    }

    private static List<Token> toRpn(List<Token> tokens) {
        List<Token> out = new List<Token>();
        List<Token> stack = new List<Token>();
        for (Token t : tokens) {
            if (t.type == 'NUM' || t.type == 'STR' || t.type == 'IDENT') out.add(t);
            else if (t.type == 'OP') {
                while (!stack.isEmpty() && stack[stack.size()-1].type == 'OP' &&
                       precedence(stack[stack.size()-1].t) >= precedence(t.t)) {
                    out.add(stack.remove(stack.size()-1));
                }
                stack.add(t);
            } else if (t.type == 'LPAR') stack.add(t);
            else if (t.type == 'RPAR') {
                Boolean found = false;
                while (!stack.isEmpty()) {
                    Token tt = stack.remove(stack.size()-1);
                    if (tt.type == 'LPAR') { found = true; break; }
                    out.add(tt);
                }
                if (!found) throw new EvalException('Mismatched parentheses');
            }
        }
        while (!stack.isEmpty()) {
            Token tt = stack.remove(stack.size()-1);
            if (tt.type == 'LPAR' || tt.type == 'RPAR') throw new EvalException('Mismatched parentheses');
            out.add(tt);
        }
        return out;
    }

    private static Boolean evaluateRpn(List<Token> rpn, Map<String,Object> candidateMap, Map<String,Object> parsedJson) {
        List<Object> st = new List<Object>();
        for (Token tk : rpn) {
            if (tk.type == 'NUM' || tk.type == 'STR' || tk.type == 'IDENT') st.add(tk);
            else if (tk.type == 'OP') {
                String op = tk.t.toUpperCase();
                if (op == 'NOT') {
                    if (st.isEmpty()) throw new EvalException('NOT requires 1 operand');
                    Object a = st.remove(st.size()-1);
                    Boolean aval = toBoolean(evalOperand(a, candidateMap, parsedJson));
                    st.add(!aval);
                } else {
                    if (st.size() < 2) throw new EvalException(op + ' requires 2 operands');
                    Object b = st.remove(st.size()-1);
                    Object a = st.remove(st.size()-1);
                    Object avalObj = evalOperand(a, candidateMap, parsedJson);
                    Object bvalObj = evalOperand(b, candidateMap, parsedJson);
                    Boolean res = evaluateBinary(op, avalObj, bvalObj);
                    st.add(res);
                }
            } else { throw new EvalException('Unexpected token type in RPN: ' + tk.type); }
        }
        if (st.size() != 1) throw new EvalException('Expression evaluated to multiple values');
        Object finalObj = st[0];
        return toBoolean(finalObj);
    }

    private static Object evalOperand(Object tokenOrValue, Map<String,Object> candidateMap, Map<String,Object> parsedJson) {
        if (tokenOrValue == null) return null;
        if (tokenOrValue instanceof Token) {
            Token tk = (Token) tokenOrValue;
            if (tk.type == 'NUM') {
                try { return Decimal.valueOf(tk.t); } catch (Exception ex) { return tk.t; }
            } else if (tk.type == 'STR') return tk.t;
            else if (tk.type == 'IDENT') return resolveIdentifier(tk.t, candidateMap, parsedJson);
        }
        return tokenOrValue;
    }

    private static Boolean toBoolean(Object o) {
        if (o == null) return false;
        if (o instanceof Boolean) return (Boolean)o;
        if (o instanceof Decimal) return ((Decimal)o) != 0;
        String s = String.valueOf(o).toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        return false;
    }

    private static Boolean evaluateBinary(String op, Object a, Object b) {
        if (op == 'CONTAINS') return containsOp(a,b);
        if (op == 'NOT_CONTAINS') return !containsOp(a,b);

        if (a instanceof Decimal || b instanceof Decimal || (isNumericString(a) && isNumericString(b))) {
            Decimal da = toDecimal(a); Decimal db = toDecimal(b);
            if (op == '==') return da == db;
            if (op == '!=') return da != db;
            if (op == '>') return da > db;
            if (op == '<') return da < db;
            if (op == '>=') return da >= db;
            if (op == '<=') return da <= db;
        }

        String sa = (a==null) ? '' : String.valueOf(a).trim();
        String sb = (b==null) ? '' : String.valueOf(b).trim();
        Integer cmp = sa.toLowerCase().compareTo(sb.toLowerCase());
        if (op == '==') return sa.toLowerCase().equals(sb.toLowerCase());
        if (op == '!=') return !sa.toLowerCase().equals(sb.toLowerCase());
        if (op == '>') return cmp > 0;
        if (op == '<') return cmp < 0;
        if (op == '>=') return cmp >= 0;
        if (op == '<=') return cmp <= 0;
        if (op == 'AND') return toBoolean(a) && toBoolean(b);
        if (op == 'OR') return toBoolean(a) || toBoolean(b);
        return false;
    }

    // Hardened containsOp: handles List<Object>, JSON arrays as strings, Map elements (look for name/value/text)
    private static Boolean containsOp(Object a, Object b) {
        if (a == null || b == null) return false;
        String needle = String.valueOf(b).toLowerCase().trim();
        try {
            // Case 1: a is a List
            if (a instanceof List<Object>) {
                for (Object it : (List<Object>) a) {
                    if (it == null) continue;
                    // If element is a primitive
                    if (it instanceof String || it instanceof Decimal || it instanceof Boolean) {
                        String its = String.valueOf(it).toLowerCase().trim();
                        if (its.equals(needle) || its.contains(needle)) return true;
                        continue;
                    }
                    // If element is a Map/object, try common string fields
                    if (it instanceof Map<String,Object>) {
                        Map<String,Object> m = (Map<String,Object>) it;
                        // look in common keys
                        for (String key : new List<String>{'name','value','text','label'}) {
                            if (m.containsKey(key)) {
                                String val = String.valueOf(m.get(key)).toLowerCase().trim();
                                if (val.equals(needle) || val.contains(needle)) return true;
                            }
                        }
                    }
                    // fallback to string representation
                    String itsFallback = String.valueOf(it).toLowerCase().trim();
                    if (itsFallback.equals(needle) || itsFallback.contains(needle)) return true;
                }
                return false;
            }

            // Case 2: a is a String that looks like a JSON array -> try to parse
            if (a instanceof String) {
                String astr = ((String)a).trim();
                if (astr.startsWith('[') && astr.endsWith(']')) {
                    try {
                        Object parsed = JSON.deserializeUntyped(astr);
                        if (parsed instanceof List<Object>) {
                            return containsOp(parsed, b);
                        }
                    } catch (Exception ex) {
                        // not parseable - fallthrough to substring check
                    }
                }
                String alow = astr.toLowerCase();
                if (alow.equals(needle) || alow.contains(needle)) return true;
                return false;
            }

            // Case 3: a is a Map - search common fields
            if (a instanceof Map<String,Object>) {
                Map<String,Object> m = (Map<String,Object>) a;
                for (String key : new List<String>{'name','value','text','label','skills'}) {
                    if (m.containsKey(key)) {
                        if (containsOp(m.get(key), b)) return true;
                    }
                }
                // fallback string
                String alow = String.valueOf(a).toLowerCase();
                return alow.contains(needle);
            }

            // Fallback: toString compare
            String as1 = String.valueOf(a).toLowerCase().trim();
            return as1.equals(needle) || as1.contains(needle);
        } catch (Exception ex) {
            // on error, be conservative and return false
            return false;
        }
    }

    private static Boolean isNumericString(Object o) {
        if (o == null) return false;
        try { String s = String.valueOf(o); Decimal.valueOf(s); return true; } catch (Exception ex) { return false; }
    }

    private static Decimal toDecimal(Object o) {
        if (o == null) return 0;
        if (o instanceof Decimal) return (Decimal)o;
        try { return Decimal.valueOf(String.valueOf(o)); } catch (Exception ex) { return 0; }
    }

    private static Object resolveIdentifier(String ident, Map<String,Object> candidateMap, Map<String,Object> parsedJson) {
        if (String.isBlank(ident)) return null;
        List<String> parts = ident.split('\\.');
        if (parts == null || parts.isEmpty()) return null;
        String root = parts[0];
        if (root == 'candidate') {
            if (candidateMap == null) return null;
            List<String> tail = buildTail(parts);
            return traverseMap(candidateMap, tail);
        } else if (root == 'parsed_json' || root == 'parsedJson' || root == 'parsedjson') {
            if (parsedJson == null) return null;
            List<String> tail = buildTail(parts);
            return traverseMap(parsedJson, tail);
        } else {
            if (candidateMap != null && candidateMap.containsKey(ident)) return candidateMap.get(ident);
            if (parsedJson != null && parsedJson.containsKey(ident)) return parsedJson.get(ident);
            return null;
        }
    }

    private static List<String> buildTail(List<String> parts) {
        List<String> tail = new List<String>();
        if (parts == null || parts.size() <= 1) return tail;
        for (Integer idx = 1; idx < parts.size(); idx++) tail.add(parts[idx]);
        return tail;
    }

    private static Object traverseMap(Map<String,Object> map1, List<String> parts) {
        Object cur = map1;
        for (String p : parts) {
            if (cur == null) return null;
            if (cur instanceof Map<String,Object>) {
                Map<String,Object> m = (Map<String,Object>) cur;
                if (!m.containsKey(p)) return null;
                cur = m.get(p);
            } else if (cur instanceof List<Object>) {
                try {
                    Integer idx = Integer.valueOf(p);
                    List<Object> lst = (List<Object>) cur;
                    if (idx < 0 || idx >= lst.size()) return null;
                    cur = lst[idx];
                } catch (Exception ex) { return null; }
            } else { return null; }
        }
        return cur;
    }
}