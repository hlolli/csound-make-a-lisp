declare pr_str(ast:S):MalValue
declare pr_str_unreadably(ast:S):MalValue

opcode MalEscapeStringForPrint(input:S):S
  indx = 0
  ilen = strlen(input)
  Sout = ""
  Sbackslash = sprintf("%c", $MAL_BACKSLASH_TOKEN)

  if (ilen > 0) then
    for indx in [0 ... ilen - 1] do
      ichar = strchar:i(input, indx)

      switch ichar
        case $MAL_DOUBLE_QUOTE_TOKEN
          Sout strcat Sout, Sbackslash
          Schar = sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
          Sout strcat Sout, Schar

        case $MAL_NEWLINE_TOKEN
          Sout strcat Sout, Sbackslash
          Sout strcat Sout, "n"

        case $MAL_BACKSLASH_TOKEN
          Sout strcat Sout, Sbackslash
          Sout strcat Sout, Sbackslash

        default
          Schar = sprintf("%c", ichar)
          Sout strcat Sout, Schar
      endsw
    od
  endif

  xout Sout
endop

opcode MalPrintPrefixedForms(ast:MalValue, prefix:S):S
  Sout = prefix
  if (ast.length > 0) then
    for indx in [0 ... ast.length - 1] do
      next:MalValue = ast.list[indx]
      Snext = pr_str(next)
      Sout strcat Sout, Snext
    od
  endif

  xout Sout
endop

opcode MalPrintDelimitedForms(ast:MalValue, left:S, right:S):S
  Sout = left
  if (ast.length > 0) then
    for indx in [0 ... ast.length - 1] do
      if (indx > 0) then
        Sout strcat Sout, " "
      endif
      Sout strcat Sout, pr_str(ast.list[indx])
    od
  endif

  Sout strcat Sout, right
  xout Sout
endop

opcode MalPrintPrefixedFormsUnreadably(ast:MalValue, prefix:S):S
  Sout = prefix
  if (ast.length > 0) then
    for indx in [0 ... ast.length - 1] do
      next:MalValue = ast.list[indx]
      Snext = pr_str_unreadably(next)
      Sout strcat Sout, Snext
    od
  endif

  xout Sout
endop

opcode MalPrintDelimitedFormsUnreadably(ast:MalValue, left:S, right:S):S
  Sout = left
  if (ast.length > 0) then
    for indx in [0 ... ast.length - 1] do
      if (indx > 0) then
        Sout strcat Sout, " "
      endif
      Sout strcat Sout, pr_str_unreadably(ast.list[indx])
    od
  endif

  Sout strcat Sout, right
  xout Sout
endop

opcode MalPrintNumber(number:i):S
  iwhole = int(number)

  if (number == iwhole) then
    Sout = sprintf("%d", iwhole)
  else
    Sout = sprintf("%g", number)
  endif

  xout Sout
endop

opcode MalPrintBuiltin(kind:S, name:S):S
  Sout = "#<"
  Sout strcat Sout, kind
  Sout strcat Sout, ":"
  Sout strcat Sout, name
  Sout strcat Sout, ">"
  xout Sout
endop

opcode pr_str_unreadably(ast:MalValue):S
  Sout = ""

  switch ast.type
    case $MAL_NUMBER_TYPE
      Snext = MalPrintNumber(ast.number)
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
      Sout = MalPrintPrefixedFormsUnreadably(ast, "'")

    case $MAL_QUASI_QUOTE_TYPE
      Sout = MalPrintPrefixedFormsUnreadably(ast, "`")

    case $MAL_UNQUOTE_TYPE
      Sout = MalPrintPrefixedFormsUnreadably(ast, "~")

    case $MAL_SPLICE_QUOTE_TYPE
      SspliceQuote = sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
      Sout = MalPrintPrefixedFormsUnreadably(ast, SspliceQuote)

    case $MAL_DEREF_TYPE
      Sderef = sprintf("%c", $MAL_AT_TOKEN)
      Sout = MalPrintPrefixedFormsUnreadably(ast, Sderef)

    case $MAL_WITH_META_TYPE
      Sout strcat Sout, "^"
      if (ast.length > 1) then
        Sout strcat Sout, pr_str_unreadably(ast.list[1])
        Sout strcat Sout, " "
        Sout strcat Sout, pr_str_unreadably(ast.list[0])
      endif

    case $MAL_LIST_TYPE
      Sout = MalPrintDelimitedFormsUnreadably(ast, "(", ")")

    case $MAL_VECTOR_TYPE
      Sout = MalPrintDelimitedFormsUnreadably(ast, "[", "]")

    case $MAL_HASH_MAP_TYPE
      Sout = MalPrintDelimitedFormsUnreadably(ast, "{", "}")

    case $MAL_BUILTIN_TYPE
      Sout = MalPrintBuiltin("builtin", ast.string)

    case $MAL_BUILTIN_OPERATOR_TYPE
      Sout = MalPrintBuiltin("builtin-operator", ast.string)

    case $MAL_BUILTIN_OPCODE_TYPE
      Sout = MalPrintBuiltin("builtin-opcode", ast.string)

    case $MAL_FUNCTION_TYPE
      Sout = sprintf("%c<function:fn*>", 35)

    case $MAL_ATOM_TYPE
      Sout strcat Sout, "(atom "
      Sout strcat Sout, pr_str_unreadably(MalAtomValue(ast))
      Sout strcat Sout, ")"
  endsw

  xout(Sout)
endop

opcode pr_str_with_readability(ast:MalValue, printReadably:i):S
  if (printReadably == 0) then
    Sout = pr_str_unreadably(ast)
  else
    Sout = pr_str(ast)
  endif

  xout Sout
endop

opcode pr_str(ast:MalValue):S
  Sout = ""

  switch ast.type
    case $MAL_NUMBER_TYPE
      Snext = MalPrintNumber(ast.number)
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
      Squote = sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
      Sout strcat Sout, Squote
      Sout strcat Sout, MalEscapeStringForPrint(ast.string)
      Sout strcat Sout, Squote

    case $MAL_QUOTE_TYPE
      Sout = MalPrintPrefixedForms(ast, "'")

    case $MAL_QUASI_QUOTE_TYPE
      Sout = MalPrintPrefixedForms(ast, "`")

    case $MAL_UNQUOTE_TYPE
      Sout = MalPrintPrefixedForms(ast, "~")

    case $MAL_SPLICE_QUOTE_TYPE
      SspliceQuote = sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
      Sout = MalPrintPrefixedForms(ast, SspliceQuote)

    case $MAL_DEREF_TYPE
      Sderef = sprintf("%c", $MAL_AT_TOKEN)
      Sout = MalPrintPrefixedForms(ast, Sderef)

    case $MAL_WITH_META_TYPE
      Sout strcat Sout, "^"
      if (ast.length > 1) then
        Sout strcat Sout, pr_str(ast.list[1])
        Sout strcat Sout, " "
        Sout strcat Sout, pr_str(ast.list[0])
      endif

    case $MAL_LIST_TYPE
      Sout = MalPrintDelimitedForms(ast, "(", ")")

    case $MAL_VECTOR_TYPE
      Sout = MalPrintDelimitedForms(ast, "[", "]")

    case $MAL_HASH_MAP_TYPE
      Sout = MalPrintDelimitedForms(ast, "{", "}")

    case $MAL_BUILTIN_TYPE
      Sout = MalPrintBuiltin("builtin", ast.string)

    case $MAL_BUILTIN_OPERATOR_TYPE
      Sout = MalPrintBuiltin("builtin-operator", ast.string)

    case $MAL_BUILTIN_OPCODE_TYPE
      Sout = MalPrintBuiltin("builtin-opcode", ast.string)

    case $MAL_FUNCTION_TYPE
      Sout = sprintf("%c<function:fn*>", 35)

    case $MAL_ATOM_TYPE
      Sout strcat Sout, "(atom "
      Sout strcat Sout, pr_str(MalAtomValue(ast))
      Sout strcat Sout, ")"
  endsw

  xout(Sout)
endop
