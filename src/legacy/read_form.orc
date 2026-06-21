// to make forward decleration possible
// we include this twice
opcode read_form, i, S[]io
  STokens[], ilength, ipos xin
  SPeek = STokens[ipos]
  prints "Speek: %s \n", SPeek
  iPeek = strchar:i(SPeek, 0)
  iret = -1
  ;; comment, ignore:
  if (strchar:i(SPeek, 0) == giSemiColon) then
    iret = -1
  elseif (iPeek == giQuote) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giQuoteType, 1, read_form(STokens, ilength, ipos))
  elseif (iPeek == giSymbolicQuote) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giQuasiQuoteType, 1, read_form(STokens, ilength, ipos))
  elseif (iPeek == giTilda) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giUnquoteType, 1, read_form(STokens, ilength, ipos))
  elseif (strcmp:i(SPeek, "~@") == 0) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giSpliceQuoteType, 1, read_form(STokens, ilength, ipos))
  elseif (iPeek == giCartot) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giWithMetaType, 1, read_form(STokens, ilength, ipos))
  elseif (iPeek == giAtSymbol) then
    ipos += 1
    iret = ftgentmp:i(0, 0, 3, -2, giDerefType, 1, read_form(STokens, ilength, ipos))
  elseif (iPeek == giParenOpen) then
    iret = read_list(STokens, ilength, giParenOpen, giListType, ipos)
  elseif (iPeek == giBracketOpen) then
    iret = read_list(STokens, ilength, giBracketOpen, giVectorType, ipos)
  elseif (iPeek == giCurlyOpen) then
    iret = read_list(STokens, ilength, giCurlyOpen, giHashMapType, ipos)
  else
    iret = read_atom(STokens, ilength, ipos)
  endif
  xout iret
endop
