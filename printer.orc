#include "constants.orc"

;; struct MalValue type:i, list:MalValue[], number:i, string:S

opcode pr_str(ast:MalValue):S
  Sout = ""
  prints "START %d \n", ast.type
  ;; if (giPLACEHOLDER == ast.type) then
  ;;   indx = 0
  ;;   prints "AST length %d \n", ast.length
  ;;   while (indx < ast.length) do
  ;;     Sout strcat Sout, pr_str(ast.list[indx])
  ;;     indx += 1
  ;;   od
  if (giNUMBER_TYPE == ast.type) then
    Snext = sprintf(" %.5f", ast.number)
    Sout strcat Sout, Snext
  elseif (giNIL_TYPE == ast.type) then
    Sout strcat Sout, " nil"
  elseif (giQUOTE_TYPE == ast.type) then
    if (ast.type == giQUOTE_TYPE) then
      prints("11 THEY ARE EQUAL FFS\n")
    else
      prints("11 WTF FFS\n")
    endif

    Sout strcat Sout, "'"
    indx = 0
    prints "QUOTE %d \n", ast.length
    while (indx < ast.length) do
      prints "PRECAT\n"
      next:MalValue = ast.list[indx]
      prints "FOO type %d\n", next.type
      Snext = pr_str(next)
      prints "BAR %s %s\n", Sout, Snext
      Sout strcat Sout, Snext
      prints "POSTCAT\n"
      indx += 1
    od
  elseif (giLIST_TYPE == ast.type) then
    prints "LIST %d \n", ast.length
    ilen = lenarray:i(ast.list)
    indx = 0
    Sout strcat Sout, "("
    while (indx < ilen) do
      Sout strcat Sout, " "
      Sout strcat Sout, pr_str(ast.list[indx])
      Sout strcat Sout, " "
      indx += 1
    od
    Sout strcat Sout, ")"
  else
    Sout = ""
    ;; prints "MALError: unhandled type %d quote-type %d number %d \n", ast.type, giQUOTE_TYPE, ast.number
  endif
  prints "Sout: %s\n", Sout
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
