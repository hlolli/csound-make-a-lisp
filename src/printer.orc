;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

declare pr_str_unreadably(ast:MalValue):(S)

opcode MalEscapeStringForPrint(input:S):S
  indx = 0
  ilen = strlen(input)
  Sout init ""
  Sbackslash init sprintf("%c", $MAL_BACKSLASH_TOKEN)

  if (ilen > 0) ithen
    for indx in [0 ... ilen - 1] do
      ichar = strchar:i(input, indx)

      switch ichar
        case $MAL_DOUBLE_QUOTE_TOKEN
          Sout strcat Sout, Sbackslash
          Schar init sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
          Sout strcat Sout, Schar

        case $MAL_NEWLINE_TOKEN
          Sout strcat Sout, Sbackslash
          Sout strcat Sout, "n"

        case $MAL_BACKSLASH_TOKEN
          Sout strcat Sout, Sbackslash
          Sout strcat Sout, Sbackslash

        default
          Schar init sprintf("%c", ichar)
          Sout strcat Sout, Schar
      endsw
    od
  endif

  xout Sout
endop

opcode MalPrintPrefixedForms(ast:MalValue, prefix:S):S
  Sout init prefix
  if (ast.length > 0) ithen
    for indx in [0 ... ast.length - 1] do
      next:MalValue init MalAt(ast, indx)
      Snext init pr_str(next)
      Sout strcat Sout, Snext
    od
  endif

  xout Sout
endop

opcode MalPrintDelimitedForms(ast:MalValue, left:S, right:S):S
  Sout init left
  if (ast.length > 0) ithen
    for indx in [0 ... ast.length - 1] do
      if (indx > 0) ithen
        Sout strcat Sout, " "
      endif
      Sout strcat Sout, pr_str(MalAt(ast, indx))
    od
  endif

  Sout strcat Sout, right
  xout Sout
endop

opcode MalPrintPrefixedFormsUnreadably(ast:MalValue, prefix:S):S
  Sout init prefix
  if (ast.length > 0) ithen
    for indx in [0 ... ast.length - 1] do
      next:MalValue init MalAt(ast, indx)
      Snext init pr_str_unreadably(next)
      Sout strcat Sout, Snext
    od
  endif

  xout Sout
endop

opcode MalPrintDelimitedFormsUnreadably(ast:MalValue, left:S, right:S):S
  Sout init left
  if (ast.length > 0) ithen
    for indx in [0 ... ast.length - 1] do
      if (indx > 0) ithen
        Sout strcat Sout, " "
      endif
      Sout strcat Sout, pr_str_unreadably(MalAt(ast, indx))
    od
  endif

  Sout strcat Sout, right
  xout Sout
endop

opcode MalPrintNumber(number:i):S
  iwhole = int(number)

  if (number == iwhole) ithen
    Sout init sprintf("%d", iwhole)
  else
    Sout init sprintf("%g", number)
  endif

  xout Sout
endop

opcode MalPrintBuiltin(kind:S, name:S):S
  Sout init "#<"
  Sout strcat Sout, kind
  Sout strcat Sout, ":"
  Sout strcat Sout, name
  Sout strcat Sout, ">"
  xout Sout
endop

opcode pr_str_unreadably(ast:MalValue):S
  Sout init ""

  switch ast.type
    case $MAL_NUMBER_TYPE
      Snext init MalPrintNumber(ast.number)
      Sout strcat Sout, Snext

    case $MAL_NIL_TYPE
      Sout strcat Sout, "nil"

    case $MAL_TRUE_TYPE
      Sout strcat Sout, "true"

    case $MAL_FALSE_TYPE
      Sout strcat Sout, "false"

    case $MAL_SYMBOL_TYPE
      Sout strcat Sout, ast.string

    case $MAL_KEYWORD_TYPE
      Sout strcat Sout, ":"
      Sout strcat Sout, ast.string

    case $MAL_STRING_TYPE
      Sout strcat Sout, ast.string

    case $MAL_QUOTE_TYPE
      Sout init MalPrintPrefixedFormsUnreadably(ast, "'")

    case $MAL_QUASI_QUOTE_TYPE
      Sout init MalPrintPrefixedFormsUnreadably(ast, "`")

    case $MAL_UNQUOTE_TYPE
      Sout init MalPrintPrefixedFormsUnreadably(ast, "~")

    case $MAL_SPLICE_QUOTE_TYPE
      SspliceQuote init sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
      Sout init MalPrintPrefixedFormsUnreadably(ast, SspliceQuote)

    case $MAL_DEREF_TYPE
      Sderef init sprintf("%c", $MAL_AT_TOKEN)
      Sout init MalPrintPrefixedFormsUnreadably(ast, Sderef)

    case $MAL_WITH_META_TYPE
      Sout strcat Sout, "^"
      if (ast.length > 1) ithen
        Sout strcat Sout, pr_str_unreadably(MalAt(ast, 1))
        Sout strcat Sout, " "
        Sout strcat Sout, pr_str_unreadably(MalAt(ast, 0))
      endif

    case $MAL_LIST_TYPE
      Sout init MalPrintDelimitedFormsUnreadably(ast, "(", ")")

    case $MAL_VECTOR_TYPE
      Sout init MalPrintDelimitedFormsUnreadably(ast, "[", "]")

    case $MAL_HASH_MAP_TYPE
      Sout init MalPrintDelimitedFormsUnreadably(ast, "{", "}")

    case $MAL_BUILTIN_TYPE
      Sout init MalPrintBuiltin("builtin", ast.string)

    case $MAL_BUILTIN_OPERATOR_TYPE
      Sout init MalPrintBuiltin("builtin-operator", ast.string)

    case $MAL_BUILTIN_OPCODE_TYPE
      Sout init MalPrintBuiltin("builtin-opcode", ast.string)

    case $MAL_FUNCTION_TYPE
      Sout init sprintf("%c<function:fn*>", 35)

    case $MAL_ATOM_TYPE
      Sout strcat Sout, "(atom "
      Sout strcat Sout, pr_str_unreadably(MalAtomValue(ast))
      Sout strcat Sout, ")"

    case $MAL_CSOUND_INSTRUMENT_TYPE
      Sout init MalPrintBuiltin("csound-instrument", ast.string)

    case $MAL_CSOUND_NODE_TYPE
      Sout init MalPrintBuiltin("csound-node", ast.string)
  endsw

  xout(Sout)
endop

opcode pr_str_with_readability(ast:MalValue, printReadably:i):S
  if (printReadably == 0) ithen
    Sout init pr_str_unreadably(ast)
  else
    Sout init pr_str(ast)
  endif

  xout Sout
endop

opcode pr_str(ast:MalValue):S
  Sout init ""

  switch ast.type
    case $MAL_NUMBER_TYPE
      Snext init MalPrintNumber(ast.number)
      Sout strcat Sout, Snext

    case $MAL_NIL_TYPE
      Sout strcat Sout, "nil"

    case $MAL_TRUE_TYPE
      Sout strcat Sout, "true"

    case $MAL_FALSE_TYPE
      Sout strcat Sout, "false"

    case $MAL_SYMBOL_TYPE
      Sout strcat Sout, ast.string

    case $MAL_KEYWORD_TYPE
      Sout strcat Sout, ":"
      Sout strcat Sout, ast.string

    case $MAL_STRING_TYPE
      Squote init sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
      Sout strcat Sout, Squote
      Sout strcat Sout, MalEscapeStringForPrint(ast.string)
      Sout strcat Sout, Squote

    case $MAL_QUOTE_TYPE
      Sout init MalPrintPrefixedForms(ast, "'")

    case $MAL_QUASI_QUOTE_TYPE
      Sout init MalPrintPrefixedForms(ast, "`")

    case $MAL_UNQUOTE_TYPE
      Sout init MalPrintPrefixedForms(ast, "~")

    case $MAL_SPLICE_QUOTE_TYPE
      SspliceQuote init sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
      Sout init MalPrintPrefixedForms(ast, SspliceQuote)

    case $MAL_DEREF_TYPE
      Sderef init sprintf("%c", $MAL_AT_TOKEN)
      Sout init MalPrintPrefixedForms(ast, Sderef)

    case $MAL_WITH_META_TYPE
      Sout strcat Sout, "^"
      if (ast.length > 1) ithen
        Sout strcat Sout, pr_str(MalAt(ast, 1))
        Sout strcat Sout, " "
        Sout strcat Sout, pr_str(MalAt(ast, 0))
      endif

    case $MAL_LIST_TYPE
      Sout init MalPrintDelimitedForms(ast, "(", ")")

    case $MAL_VECTOR_TYPE
      Sout init MalPrintDelimitedForms(ast, "[", "]")

    case $MAL_HASH_MAP_TYPE
      Sout init MalPrintDelimitedForms(ast, "{", "}")

    case $MAL_BUILTIN_TYPE
      Sout init MalPrintBuiltin("builtin", ast.string)

    case $MAL_BUILTIN_OPERATOR_TYPE
      Sout init MalPrintBuiltin("builtin-operator", ast.string)

    case $MAL_BUILTIN_OPCODE_TYPE
      Sout init MalPrintBuiltin("builtin-opcode", ast.string)

    case $MAL_FUNCTION_TYPE
      Sout init sprintf("%c<function:fn*>", 35)

    case $MAL_ATOM_TYPE
      Sout strcat Sout, "(atom "
      Sout strcat Sout, pr_str(MalAtomValue(ast))
      Sout strcat Sout, ")"

    case $MAL_CSOUND_INSTRUMENT_TYPE
      Sout init MalPrintBuiltin("csound-instrument", ast.string)

    case $MAL_CSOUND_NODE_TYPE
      Sout init MalPrintBuiltin("csound-node", ast.string)
  endsw

  xout(Sout)
endop
