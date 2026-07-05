;; Csound's declare type order is reversed relative to typed opcode definitions.
declare read_form(reader:MalReadResult):MalReader

opcode isCharWordBoundry(char:i):i
  ires = 0
  if (char == $MAL_NEWLINE_TOKEN || \
      char == $MAL_SPACE_TOKEN || \
      char == $MAL_TAB_TOKEN || \
      char == $MAL_SEMICOLON_TOKEN || \
      char == $MAL_DOUBLE_QUOTE_TOKEN || \
      char == $MAL_PAREN_OPEN_TOKEN || \
      char == $MAL_PAREN_CLOSE_TOKEN || \
      char == $MAL_CURLY_OPEN_TOKEN || \
      char == $MAL_CURLY_CLOSE_TOKEN  || \
      char == $MAL_BRACKET_OPEN_TOKEN  || \
      char == $MAL_BRACKET_CLOSE_TOKEN) \
      then
    ires = 1
  endif
  xout(ires)
endop

opcode nextWordBoundry(input:S, from:i, maxLookahead:i):i
  indx = from
  ifound = 0
  while (indx < maxLookahead && ifound == 0) do
    ipeek = strchar:i(input, indx)
    if (isCharWordBoundry(ipeek) == 1) then
      ifound = 1
    else
      indx += 1
    endif
  od

  xout(min:i(indx, maxLookahead))
endop

opcode nextEndOfLine(input:S, from:i, maxLookahead:i):i
  indx = from
  ifound = 0
  while (indx < maxLookahead && ifound == 0) do
    ipeek = strchar:i(input, indx)
    if (ipeek == $MAL_NEWLINE_TOKEN) then
      ifound = 1
    else
      indx += 1
    endif
  od
  xout(min:i(indx, maxLookahead))
endop

opcode nextStringTokenDelimiter(input:S, from:i, maxLookahead:i):i
  indx = from + 1
  ifound = 0
  iescaped = 0

  while (indx < maxLookahead && ifound == 0) do
    ipeek = strchar:i(input, indx)

    if (iescaped == 1) then
      iescaped = 0
      indx += 1
    elseif (ipeek == $MAL_BACKSLASH_TOKEN) then
      iescaped = 1
      indx += 1
    elseif (ipeek == $MAL_DOUBLE_QUOTE_TOKEN) then
      ifound = indx + 1
    else
      indx += 1
    endif
  od

  xout(ifound == 0 ? maxLookahead : ifound)
endop

opcode findNumberTokenDelimiter(input:S, from:i, maxLookahead:i):i
  indx = from
  ifound = 0
  iperiodCount = 0

  if (indx < maxLookahead && strchar:i(input, indx) == $MAL_MINUS_TOKEN) then
    indx += 1
  endif

  while (indx < maxLookahead && ifound == 0) do
    ipeek = strchar:i(input, indx)

    if (ipeek >= 48 && ipeek < 58) then
      indx += 1
    elseif (ipeek == $MAL_PERIOD_TOKEN && iperiodCount == 0) then
      indx += 1
      iperiodCount = 1
    elseif isCharWordBoundry(ipeek) == 1 then
      ifound = indx
    else
      // error
      ifound = -1
    endif
  od

  xout(ifound == 0 ? indx : ifound)
endop

opcode tokenize(input:S):MalTokens
  istrLen = strlen(input)
  STokens[] init istrLen + 256 // maximum possible token count and more

  itokenCnt = 0
  indx = 0
  ierror = 0

  while indx < istrLen && ierror == 0 do
    icharsLeft = istrLen - indx
    ipeek  = strchar:i(input, indx)
    ipeek2 = indx + 1 < istrLen ? strchar:i(input, indx + 1) : -1
    ;; prints "ipeek %d ipeek2 %d \n", ipeek, ipeek2

    ;; ignore whitespaces and commas
    if (ipeek == $MAL_SPACE_TOKEN || ipeek == $MAL_COMMA_TOKEN || ipeek == $MAL_NEWLINE_TOKEN) then
      indx += 1
      igoto END
    endif

    ;; jump over line comments
    if (ipeek == $MAL_SEMICOLON_TOKEN) then
      inextNewline = nextEndOfLine(input, indx, istrLen)
      indx = inextNewline
      igoto END
    endif

    ;; test for ~@ token
    if (ipeek == $MAL_TILDE_TOKEN && ipeek2 == $MAL_AT_TOKEN) then
      STokens[itokenCnt] = strcpy(strsub(input, indx, indx + 2))
      itokenCnt += 1
      indx += 2
      igoto END
    endif

    ;; capture strings, including escaped quotes and unterminated strings
    if (ipeek == $MAL_DOUBLE_QUOTE_TOKEN) then
      inextString = nextStringTokenDelimiter(input, indx, istrLen)
      STokens[itokenCnt] = strcpy(strsub(input, indx, inextString))
      itokenCnt += 1
      indx = inextString
      igoto END
    endif

    ;; capture numbers, including a leading minus followed by a digit
    if ((ipeek >= 48 && ipeek < 58) || \
        (ipeek == $MAL_MINUS_TOKEN && ipeek2 >= 48 && ipeek2 < 58)) then
      inumberDelim = findNumberTokenDelimiter(input, indx, istrLen)

      if inumberDelim > -1 then
        ;; prints "number: %s\n", strsub(input, indx, inumberDelim)
        STokens[itokenCnt] = strcpy(strsub(input, indx, inumberDelim))
        itokenCnt += 1
        indx = inumberDelim
      else
        ierror = inumberDelim
      endif
      igoto END
    endif

    ;; test for any single special token [\[\]{}()'`~^@]
    if (ipeek == $MAL_TILDE_TOKEN || \
        ipeek == $MAL_CURLY_OPEN_TOKEN || \
        ipeek == $MAL_CURLY_CLOSE_TOKEN || \
        ipeek == $MAL_BRACKET_OPEN_TOKEN || \
        ipeek == $MAL_BRACKET_CLOSE_TOKEN || \
        ipeek == $MAL_PAREN_OPEN_TOKEN || \
        ipeek == $MAL_PAREN_CLOSE_TOKEN || \
        ipeek == $MAL_SINGLE_QUOTE_TOKEN || \
        ipeek == $MAL_BACKTICK_TOKEN || \
        ipeek == $MAL_AT_TOKEN || \
        ipeek == $MAL_CARET_TOKEN) then
      STokens[itokenCnt] = strcpy(strsub(input, indx, indx + 1))
      itokenCnt += 1
      indx += 1
      igoto END
    endif

    ;; default case: capture delimited tokens (symbols)
    inextBoundry = nextWordBoundry(input, indx, istrLen)
    SNext = strsub(input, indx, inextBoundry)
    ;; prints "SNext %s %d\n", SNext, itokenCnt
    STokens[itokenCnt] = SNext
    itokenCnt += 1
    indx = inextBoundry

  END:
    od

    tstruct:MalTokens init itokenCnt, STokens
    xout(tstruct)
endop

;; function read_atom (reader) {
;;     const token = reader.next()
;;     //console.log("read_atom:", token)
;;     if (token.match(/^-?[0-9]+$/)) {
;;         return parseInt(token,10)        // integer
;;     } else if (token.match(/^-?[0-9][0-9.]*$/)) {
;;         return parseFloat(token,10)     // float
;;     } else if (token.match(/^"(?:\\.|[^\\"])*"$/)) {
;;         return token.slice(1,token.length-1)
;;             .replace(/\\(.)/g, (_, c) => c === "n" ? "\n" : c)
;;     } else if (token[0] === "\"") {
;;         throw new Error("expected '\"', got EOF");
;;     } else if (token[0] === ":") {
;;         return _keyword(token.slice(1))
;;     } else if (token === "nil") {
;;         return null
;;     } else if (token === "true") {
;;         return true
;;     } else if (token === "false") {
;;         return false
;;     } else {
;;         return Symbol.for(token) // symbol
;;     }
;; }

opcode MalDecodeStringToken(token:S):S
  itokenLen = strlen(token)
  indx = 1
  Sout = ""

  while (indx < itokenLen - 1) do
    ichar = strchar:i(token, indx)

    if (ichar == $MAL_BACKSLASH_TOKEN && indx + 1 < itokenLen - 1) then
      inext = strchar:i(token, indx + 1)

      if (inext == 110) then
        Schar = sprintf("%c", $MAL_NEWLINE_TOKEN)
      else
        Schar = sprintf("%c", inext)
      endif

      Sout strcat Sout, Schar
      indx += 2
    else
      Schar = sprintf("%c", ichar)
      Sout strcat Sout, Schar
      indx += 1
    endif
  od

  xout Sout
endop


opcode read_atom(reader:MalReader):MalValue
  Stoken = reader.peek
  v:MalValue = MalMkValue($MAL_NUMBER_TYPE)
  itokenLen = strlen(Stoken)
  ifirstChar = strchar:i(Stoken, 0)
  ilastChar = itokenLen > 0 ? strchar:i(Stoken, itokenLen - 1) : -1

  if (ifirstChar == $MAL_DOUBLE_QUOTE_TOKEN && ilastChar != $MAL_DOUBLE_QUOTE_TOKEN) then
    v = MalMkError("expected '\"', got EOF")
  elseif (ifirstChar == $MAL_DOUBLE_QUOTE_TOKEN) then
    v.type = $MAL_STRING_TYPE
    v.string = MalDecodeStringToken(Stoken)
  elseif (ifirstChar == $MAL_COLON_TOKEN) then
    v.type = $MAL_KEYWORD_TYPE
    v.string = strsub(Stoken, 1, itokenLen)
  elseif MalIsNumericString(Stoken) == 1 then
    v.type = $MAL_NUMBER_TYPE
    inum = strtod:i(Stoken)
    v.number = inum
  elseif strcmp("nil", Stoken) == 0 then
    v.type = $MAL_NIL_TYPE
  elseif strcmp("true", Stoken) == 0 then
    v.type = $MAL_TRUE_TYPE
  elseif strcmp("false", Stoken) == 0 then
    v.type = $MAL_FALSE_TYPE
  else
    v.type = $MAL_SYMBOL_TYPE
    v.string = Stoken
  endif

  xout v
endop

opcode read_sequence(reader:MalReader, endToken:S, sequenceType:i):MalReadResult
  newSequence:MalValue = MalMkValue(sequenceType)
  currentToken:MalReader = MalNextToken(reader)
  ierror = 0
  ifoundEnd = 0

  while(ifoundEnd == 0 && ierror == 0) do
    if currentToken.done == 1 then
      newSequence = MalMkError(sprintf("expected '%s', got EOF", endToken))
      ierror = 1
    elseif strcmp(currentToken.peek, endToken) == 0 then
      ifoundEnd = 1
    else
      next:MalReadResult = read_form(currentToken)
      nextValue:MalValue = MalReadResultValue(next)
      newSequence = MalAppendValue(newSequence, nextValue)
      currentToken = MalReadResultReader(next)

      if next.type == $MAL_ERROR_TYPE then
        ierror = 1
      endif
    endif
  od

  if ierror == 0 then
    currentToken = MalNextToken(currentToken)
  endif

  xout MalMkReadResult(newSequence, currentToken)

endop

opcode read_list(reader:MalReader, endToken:S):MalReadResult
  xout read_sequence(reader, endToken, $MAL_LIST_TYPE)
endop

opcode read_vector(reader:MalReader, endToken:S):MalReadResult
  xout read_sequence(reader, endToken, $MAL_VECTOR_TYPE)
endop

opcode read_hash_map(reader:MalReader, endToken:S):MalReadResult
  xout read_sequence(reader, endToken, $MAL_HASH_MAP_TYPE)
endop

opcode read_reader_macro(reader:MalReader, macroSymbol:S, macroToken:S):MalReadResult
  v:MalValue = MalMkValue($MAL_LIST_TYPE)
  reader = MalNextToken(reader)

  if reader.done == 1 then
    v = MalMkError(sprintf("expected form after '%s', got EOF", macroToken))
    xout MalMkReadResult(v, reader)
  else
    next:MalReadResult = read_form(reader)
    nextValue:MalValue = MalReadResultValue(next)
    v = MalMkList2(MalMkSymbol(macroSymbol), nextValue)
    xout MalMkReadResult(v, MalReadResultReader(next))
  endif
endop

opcode read_with_meta(reader:MalReader):MalReadResult
  v:MalValue = MalMkValue($MAL_LIST_TYPE)
  reader = MalNextToken(reader)

  if reader.done == 1 then
    v = MalMkError("expected metadata after '^', got EOF")
    xout MalMkReadResult(v, reader)
  else
    meta:MalReadResult = read_form(reader)
    metaValue:MalValue = MalReadResultValue(meta)
    formReader:MalReader = MalReadResultReader(meta)

    if (meta.type == $MAL_ERROR_TYPE) then
      xout meta
    elseif formReader.done == 1 then
      v = MalMkError("expected form after '^' metadata, got EOF")
      xout MalMkReadResult(v, formReader)
    else
      form:MalReadResult = read_form(formReader)
      formValue:MalValue = MalReadResultValue(form)
      v = MalMkList3(MalMkSymbol("with-meta"), formValue, metaValue)
      xout MalMkReadResult(v, MalReadResultReader(form))
    endif
  endif
endop


opcode read_form(reader:MalReader):MalReadResult
  Stoken = reader.peek
  itokenLen = strlen(Stoken)
  istrChar  = strchar:i(Stoken, 0)
  if strcmp("(", Stoken) == 0 then
    xout read_list(reader, ")")
  elseif strcmp("[", Stoken) == 0 then
    xout read_vector(reader, "]")
  elseif strcmp("{", Stoken) == 0 then
    xout read_hash_map(reader, "}")
  elseif strcmp("'", Stoken) == 0 then
    xout read_reader_macro(reader, "quote", "'")
  elseif strcmp("`", Stoken) == 0 then
    xout read_reader_macro(reader, "quasiquote", "`")
  elseif (itokenLen == 2 && istrChar == $MAL_TILDE_TOKEN && \
          strchar:i(Stoken, 1) == $MAL_AT_TOKEN) then
    SspliceQuote = sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
    xout read_reader_macro(reader, "splice-unquote", SspliceQuote)
  elseif strcmp("~", Stoken) == 0 then
    xout read_reader_macro(reader, "unquote", "~")
  elseif (itokenLen == 1 && istrChar == $MAL_AT_TOKEN) then
    Sderef = sprintf("%c", $MAL_AT_TOKEN)
    xout read_reader_macro(reader, "deref", Sderef)
  elseif strcmp("^", Stoken) == 0 then
    xout read_with_meta(reader)
  ;; elseif istrChar >= 48 && istrChar < 58 then
  ;;   v:MalValue = mkValue($MAL_NUMBER_TYPE)
  ;;   v.number = strtol(Stoken)
  ;;   reader = nextToken(reader)
  ;;   l:MalValue[] = v.list
  ;;   car:MalValue = l[0]
  ;;   car = read_form(reader)
  ;;   xout v
  else
    v:MalValue = read_atom(reader)
    xout MalMkReadResult(v, MalNextToken(reader))
    ;; v:MalValue = mkValue(giPLACEHOLDER)
    ;; xout v
  endif

  ;; reader = nextToken(reader)
  ;; if reader.done != 1 then
  ;;   read_form(reader)
  ;; endif
  ;; xout(ast)
endop

opcode read_str(input:S):MalValue
  tstruct:MalTokens = tokenize(input)
  reader:MalReader = MalMkReader(tstruct)
  result:MalReadResult = read_form(reader)
  xout MalReadResultValue(result)
endop
