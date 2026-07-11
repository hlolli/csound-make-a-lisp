#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop

opcode PRINT(ast:MalValue):S
  xout pr_str_with_readability(ast, 1)
endop

opcode REP_ENV(input:S, env:MalEnv):(S, MalEnv)
  ast:MalValue = READ(input)
  currentEnv:MalEnv = env

  if (ast.type == $MAL_ERROR_TYPE) then
    result:S = ast.string
  else
    evaluated:MalValue, currentEnv = EVAL_ENV(ast, currentEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated.string
    else
      result = PRINT(evaluated)
    endif
  endif

  xout result, currentEnv
endop

opcode ASSERT_REP_ENV(input:S, expected:S, env:MalEnv):MalEnv
  actual:S, updatedEnv:MalEnv = REP_ENV(input, env)

  if (strcmp(actual, expected) == 0) then
    prints "STEP6 %s, Assertion success\n", input
  else
    prints "STEP6 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 6 file and reader builtins\n"
  env:MalEnv = MalMkStep6Env()

  env = ASSERT_REP_ENV("(list? *ARGV*)", "true", env)
  env = ASSERT_REP_ENV("*ARGV*", "()", env)
  env = ASSERT_REP_ENV("(read-string \"(+ 2 3)\")", "(+ 2 3)", env)
  env = ASSERT_REP_ENV("(read-string \"(1 2 (3 4) nil)\")", \
    "(1 2 (3 4) nil)", env)
  env = ASSERT_REP_ENV("(= nil (read-string \"nil\"))", "true", env)
  env = ASSERT_REP_ENV("(read-string \"7 ;; comment\")", "7", env)
  env = ASSERT_REP_ENV("(str \"(do \" \"(+ 1 2)\" \"\\nnil)\")", \
    "\"(do (+ 1 2)\\nnil)\"", env)
  env = ASSERT_REP_ENV("(slurp \"mal/tests/test.txt\")", \
    "\"A line of text\\n\"", env)
  env = ASSERT_REP_ENV("(slurp \"mal/tests/test.txt\")", \
    "\"A line of text\\n\"", env)
  env = ASSERT_REP_ENV("(eval (read-string \"(+ 2 3)\"))", "5", env)
  env = ASSERT_REP_ENV("(let* (b 12) (do (eval (read-string \"(def! aa 7)\")) aa))", \
    "7", env)
  env = ASSERT_REP_ENV("aa", "7", env)
  env = ASSERT_REP_ENV("(def! a 1)", "1", env)
  env = ASSERT_REP_ENV("(let* (a 2) (eval (read-string \"a\")))", "1", env)
  env = ASSERT_REP_ENV("(load-file \"mal/tests/inc.mal\")", "nil", env)
  env = ASSERT_REP_ENV("(inc1 7)", "8", env)
  env = ASSERT_REP_ENV("(inc2 7)", "9", env)
  env = ASSERT_REP_ENV("(inc3 9)", "12", env)
  env = ASSERT_REP_ENV("(def! a (atom 2))", "(atom 2)", env)
  env = ASSERT_REP_ENV("(atom? a)", "true", env)
  env = ASSERT_REP_ENV("(atom? 1)", "false", env)
  env = ASSERT_REP_ENV("(deref a)", "2", env)
  env = ASSERT_REP_ENV("(reset! a 3)", "3", env)
  env = ASSERT_REP_ENV("(deref a)", "3", env)
  env = ASSERT_REP_ENV("(swap! a + 4)", "7", env)
  env = ASSERT_REP_ENV("(deref a)", "7", env)
  env = ASSERT_REP_ENV("(def! inc-it (fn* (n) (+ n 1)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(def! bump (fn* () (swap! a inc-it)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(bump)", "8", env)
  env = ASSERT_REP_ENV("(bump)", "9", env)
  env = ASSERT_REP_ENV("(def! retained (let* (cell (atom 0)) (fn* () (deref cell))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(def! cell (atom 1))", "(atom 1)", env)
  env = ASSERT_REP_ENV("(retained)", "0", env)

  atomValue:MalValue = MalMkString("first")
  atom:MalValue = MalMkAtom(atomValue)
  atomAlias:MalValue = atom
  updatedValue:MalValue = MalMkString("second")
  ignored:MalValue = MalAtomSetValue(atomAlias, updatedValue)
  otherAtom:MalValue = MalMkAtom(updatedValue)

  for index in [0 ... 7] do
    extraValue:MalValue = MalMkValue($MAL_NUMBER_TYPE)
    extraValue.number = index
    extraAtom:MalValue = MalMkAtom(extraValue)
  od

  if (atom.type != $MAL_ATOM_TYPE || MalEquals(atom, atomAlias) == 0 || \
      MalEquals(atom, otherAtom) == 1 || \
      strcmp(pr_str(atom), "(atom \"second\")") != 0 || \
      strcmp(pr_str_unreadably(atom), "(atom second)") != 0) then
    prints "STEP6 atom representation, Assertion failed: got '%s'\n", \
      pr_str(atom)
    exitnow(1)
  else
    prints "STEP6 atom representation, Assertion success\n"
  endif
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
