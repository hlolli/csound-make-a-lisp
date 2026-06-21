opcode READ, S[], S
  STR xin
  STokens[] fillarray STR
  xout STokens
endop

opcode EVAL, S[], S[]i[]
  S_AST[], iEnv[] xin
  xout S_AST
endop

opcode PRINT, S[], S[]
  S_EXP[] xin
  indx = 0
  until indx == lenarray(S_EXP) do
  prints "%s\n", S_EXP[indx]
  indx += 1
  od
  xout S_EXP
endop

opcode REPL, S[], S
  STR xin
  ienv[] init 1
  STokz[] = READ(STR)
  xout PRINT(EVAL(STokz, ienv))
endop

instr TEST
  Sexpect = "1.00"
  SRead[] = READ(Sexpect)
  if (strcmp(SRead[0], Sexpect) == 0) then
    prints "READ, Assertion success\n"
  else
    prints "READ, Assertion failed\n"
  endif
  ienv[] init 1
  SExpect2[] fillarray "hello", "world"
  SRes[] = EVAL(SExpect2, ienv)
  if (strcmp(SRes[0], SExpect2[0]) == 0 && strcmp(SRes[1], SExpect2[1]) == 0) then
    prints "EVAL, Assertion success\n"
  else
    prints "EVAL, Assertion failed\n"
  endif
  SReplRes[] = REPL("Hello World")
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
