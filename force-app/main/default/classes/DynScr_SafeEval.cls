public with sharing class DynScr_SafeEval {

    public static Boolean execute(String expr) {
        expr = expr.replace('==', '=');
        ExprParser p = new ExprParser(expr);
        return p.parse();
    }

    private class ExprParser {
        private List<String> tokens;
        private Integer index = 0;

        ExprParser(String expr) {
            tokens = expr.replace('(', ' ( ').replace(')', ' ) ').split(' ');
        }

        Boolean parse() {
            return parseOr();
        }

        Boolean parseOr() {
            Boolean left = parseAnd();
            while (match('OR')) {
                Boolean right = parseAnd();
                left = left || right;
            }
            return left;
        }

        Boolean parseAnd() {
            Boolean left = parseAtom();
            while (match('AND')) {
                Boolean right = parseAtom();
                left = left && right;
            }
            return left;
        }

        Boolean parseAtom() {
            if (match('(')) {
                Boolean val = parseOr();
                match(')');
                return val;
            }
            return parseComparison();
        }

        Boolean parseComparison() {
            String left = nextToken();
            String op = nextToken();
            String right = nextToken();

            if (left == null || op == null || right == null)
                return false;

            left = left.replace('\'','');
            right = right.replace('\'','');

            if (op == '=') return left == right;
            if (op == '!=') return left != right;
            if (left.isNumeric() && right.isNumeric()) {
                Decimal l = Decimal.valueOf(left);
                Decimal r = Decimal.valueOf(right);
                if (op == '>') return l > r;
                if (op == '<') return l < r;
                if (op == '>=') return l >= r;
                if (op == '<=') return l <= r;
            }
            return false;
        }

        Boolean match(String t) {
            if (peek() != null && peek().toUpperCase() == t) {
                index++;
                return true;
            }
            return false;
        }

        String nextToken() {
            if (index >= tokens.size()) return null;
            return tokens[index++].trim();
        }

        String peek() {
            if (index >= tokens.size()) return null;
            return tokens[index].trim();
        }
    }
}
