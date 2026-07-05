;; struct MalValue type:i, list:MalValue[], number:i, string:S

declare pr_str(ast:S):MalValue

opcode MalEscapeStringForPrint(input:S):S
  indx = 0
  ilen = strlen(input)
  Sout = ""
  Sbackslash = sprintf("%c", $MAL_BACKSLASH_TOKEN)

  while (indx < ilen) do
    ichar = strchar:i(input, indx)

    if (ichar == $MAL_DOUBLE_QUOTE_TOKEN) then
      Sout strcat Sout, Sbackslash
      Schar = sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
      Sout strcat Sout, Schar
    elseif (ichar == $MAL_NEWLINE_TOKEN) then
      Sout strcat Sout, Sbackslash
      Sout strcat Sout, "n"
    elseif (ichar == $MAL_BACKSLASH_TOKEN) then
      Sout strcat Sout, Sbackslash
      Sout strcat Sout, Sbackslash
    else
      Schar = sprintf("%c", ichar)
      Sout strcat Sout, Schar
    endif

    indx += 1
  od

  xout Sout
endop

opcode MalPrintPrefixedForms(ast:MalValue, prefix:S):S
  Sout = prefix
  indx = 0

  while (indx < ast.length) do
    next:MalValue = ast.list[indx]
    Snext = pr_str(next)
    Sout strcat Sout, Snext
    indx += 1
  od

  xout Sout
endop

opcode MalPrintDelimitedForms(ast:MalValue, left:S, right:S):S
  Sout = left
  indx = 0

  while (indx < ast.length) do
    if (indx > 0) then
      Sout strcat Sout, " "
    endif
    Sout strcat Sout, pr_str(ast.list[indx])
    indx += 1
  od

  Sout strcat Sout, right
  xout Sout
endop

opcode pr_str(ast:MalValue):S
  Sout = ""
  if ($MAL_NUMBER_TYPE == ast.type) then
    Snext = sprintf("%.5f", ast.number)
    Sout strcat Sout, Snext
  elseif ($MAL_NIL_TYPE == ast.type) then
    Sout strcat Sout, "nil"
  elseif ($MAL_TRUE_TYPE == ast.type) then
    Sout strcat Sout, "true"
  elseif ($MAL_FALSE_TYPE == ast.type) then
    Sout strcat Sout, "false"
  elseif ($MAL_SYMBOL_TYPE == ast.type) then
    Sout strcat Sout, ast.string
  elseif ($MAL_KEYWORD_TYPE == ast.type) then
    Sout strcat Sout, ":"
    Sout strcat Sout, ast.string
  elseif ($MAL_STRING_TYPE == ast.type) then
    Squote = sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
    Sout strcat Sout, Squote
    Sout strcat Sout, MalEscapeStringForPrint(ast.string)
    Sout strcat Sout, Squote
  elseif ($MAL_QUOTE_TYPE == ast.type) then
    Sout = MalPrintPrefixedForms(ast, "'")
  elseif ($MAL_QUASI_QUOTE_TYPE == ast.type) then
    Sout = MalPrintPrefixedForms(ast, "`")
  elseif ($MAL_UNQUOTE_TYPE == ast.type) then
    Sout = MalPrintPrefixedForms(ast, "~")
  elseif ($MAL_SPLICE_QUOTE_TYPE == ast.type) then
    SspliceQuote = sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
    Sout = MalPrintPrefixedForms(ast, SspliceQuote)
  elseif ($MAL_DEREF_TYPE == ast.type) then
    Sderef = sprintf("%c", $MAL_AT_TOKEN)
    Sout = MalPrintPrefixedForms(ast, Sderef)
  elseif ($MAL_WITH_META_TYPE == ast.type) then
    Sout strcat Sout, "^"
    if (ast.length > 1) then
      Sout strcat Sout, pr_str(ast.list[1])
      Sout strcat Sout, " "
      Sout strcat Sout, pr_str(ast.list[0])
    endif
  elseif ($MAL_LIST_TYPE == ast.type) then
    Sout = MalPrintDelimitedForms(ast, "(", ")")
  else
    Sout = ""
    ;; prints "MALError: unhandled type %d quote-type %d number %d \n", ast.type, $MAL_QUOTE_TYPE, ast.number
  endif
  xout(Sout)
endop

  ;; indx = 0
  ;; Sout = ""
  ;; while (indx < ast.length) do
  ;;   Stokens[] = tstruct.tokens
  ;;   Stok = Stokens[indx]
  ;;   Sout = strcat(Sout, strcat(" ", Stok))
  ;;   indx += 1
  ;; od
  ;; xout Sout

;; opcode pr_str_old, S, i
;;   iast xin
;;   if (iast > 0) then
;;     Sout = ""
;;     itype = tab_i(0, iast)
;;     if (itype == giNumberType) then
;;       Sout = sprintf("%d", tab_i(2, iast))
;;     elseif (itype == giStringType) then
;;       ilen = tab_i(1, iast)
;;       idx = 0
;;       SfromAscii = ""
;;       while idx < ilen do
;;         SfromAscii = strcat(SfromAscii, sprintf("%c", tab_i(2 + idx, iast)))
;;         idx += 1
;;       od
;;       Sout = sprintf("\"%s\"", SfromAscii)
;;     elseif (itype == giKeywordType) then
;;       ilen = tab_i(1, iast)
;;       idx = 0
;;       SfromAscii = ""
;;       while idx < ilen do
;;         SfromAscii = strcat(SfromAscii, sprintf("%c", tab_i(2 + idx, iast)))
;;         idx += 1
;;       od
;;       Sout = sprintf(":%s", SfromAscii)
;;     elseif (itype == giListType) then
;;       ilen = tab_i(1, iast)
;;       print ilen
;;       idx = 0
;;       while idx < ilen do
;;         Snext = pr_str_old(tab_i(2 + idx, iast))
;;         ;; join " "
;;         if idx > 0 then
;;           Sout = strcat(" ", Snext)
;;         else
;;           Sout = Snext
;;         endif
;;       od
;;     elseif (itype == giNilType) then
;;       Sout = "nil"
;;     elseif (itype == giTrueType) then
;;       Sout = "true"
;;     elseif (itype == giFalseType) then
;;       Sout = "false"
;;     else
;;       ilen = tab_i(1, iast)
;;       idx = 0
;;       SfromAscii = ""
;;       while idx < ilen do
;;         SfromAscii = strcat(SfromAscii, sprintf("%c", tab_i(2 + idx, iast)))
;;         idx += 1
;;       od
;;       Sout = SfromAscii
;;     endif
;;   endif
;;   xout Sout
;; endop
