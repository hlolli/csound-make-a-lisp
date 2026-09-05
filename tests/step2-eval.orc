;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop

opcode PRINT(ast:MalValue):S
  xout pr_str_with_readability(ast, 1)
endop

opcode REP(input:S, env:MalEnv):S
  ast:MalValue = READ(input)

  if (ast.type == $MAL_ERROR_TYPE) then
    result:S = ast.string
  else
    evaluated:MalValue = EVAL(ast, env)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated.string
    else
      result = PRINT(evaluated)
    endif
  endif

  xout result
endop

opcode ASSERT_REP(input:S, expected:S, env:MalEnv):void
  actual:S = REP(input, env)

  if (strcmp(actual, expected) == 0) then
    prints "EVAL %s, Assertion success\n", input
  else
    prints "EVAL %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif
endop

opcode ASSERT_EVAL_TYPE(input:S, expectedType:i, expectedString:S, env:MalEnv):void
  actual:MalValue = EVAL(READ(input), env)

  if (actual.type != expectedType) then
    prints "EVAL type %s, Assertion failed: expected type=%d, got type=%d\n", \
      input, expectedType, actual.type
    exitnow(1)
  elseif (strcmp(actual.string, expectedString) != 0) then
    prints "EVAL type %s, Assertion failed: expected string='%s', got '%s'\n", \
      input, expectedString, actual.string
    exitnow(1)
  else
    prints "EVAL type %s, Assertion success\n", input
  endif
endop

instr TEST
  prints "Testing Step 2 arithmetic evaluation\n"
  envArithmetic:MalEnv = MalMkStep2Env()
  ASSERT_REP("(+ 1 2)", "3", envArithmetic)
  ASSERT_REP("(- 7 3)", "4", envArithmetic)
  ASSERT_REP("(* 6 7)", "42", envArithmetic)
  ASSERT_REP("(/ 9 4)", "2", envArithmetic)
  ASSERT_REP("(* -3 6)", "-18", envArithmetic)
  ASSERT_REP("(+ 5 (* 2 3))", "11", envArithmetic)
  ASSERT_REP("(- (+ 5 (* 2 3)) 3)", "8", envArithmetic)
  ASSERT_REP("(/ (- (+ 515 (* 87 311)) 302) 27)", "1010", envArithmetic)
  ASSERT_REP("(/ (- (+ 515 (* -87 311)) 296) 27)", "-994", envArithmetic)

  prints "Testing Step 2 environment lookup and errors\n"
  envErrors:MalEnv = MalMkStep2Env()
  ASSERT_EVAL_TYPE("+", $MAL_BUILTIN_OPERATOR_TYPE, "+", envErrors)
  ASSERT_EVAL_TYPE("-", $MAL_BUILTIN_OPERATOR_TYPE, "-", envErrors)
  ASSERT_REP("abc", "'abc' not found", envErrors)
  ASSERT_REP("(abc 1 2 3)", "'abc' not found", envErrors)
  ASSERT_REP("(1 2)", "cannot apply 1", envErrors)
  ASSERT_REP("(+ 1)", "+: expected 2 arguments, got 1", envErrors)
  ASSERT_REP("(+ 1 2 3)", "+: expected 2 arguments, got 3", envErrors)
  ASSERT_REP("(+ 1 \"two\")", "+: expected numeric arguments", envErrors)
  ASSERT_REP("(/ 1 0)", "/: division by zero", envErrors)

  prints "Testing Step 2 collection evaluation\n"
  envCollections:MalEnv = MalMkStep2Env()
  ASSERT_REP("()", "()", envCollections)
  ASSERT_REP("[]", "[]", envCollections)
  ASSERT_REP("{}", "{}", envCollections)
  ASSERT_REP("[nil true false]", "[nil true false]", envCollections)
  ASSERT_REP("[1 2 (+ 1 2)]", "[1 2 3]", envCollections)
  ASSERT_REP("[+ 1 2]", "[#<builtin-operator:+> 1 2]", envCollections)
  ASSERT_REP("{\"a\" (+ 7 8)}", "{\"a\" 15}", envCollections)
  ASSERT_REP("{:a (+ 7 8)}", "{:a 15}", envCollections)
  ASSERT_REP("{:a [1 (+ 1 2)]}", "{:a [1 3]}", envCollections)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
