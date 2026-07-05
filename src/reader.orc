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

opcode findNumberTokenDelimiter(input:S, from:i, maxLookahead:i):i
  indx = from
  ifound = 0
  iperiodCount = 0

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

    ;; capture numbers
    if ipeek >= 48 && ipeek < 58 then
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
        ipeek == $MAL_COLON_TOKEN || \
        ipeek == $MAL_DOUBLE_QUOTE_TOKEN || \
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


opcode read_atom(reader:MalReader):MalValue
  Stoken = reader.peek
  v:MalValue = MalMkValue($MAL_NUMBER_TYPE)

  if MalIsNumericString(Stoken) == 1 then
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

opcode read_list(reader:MalReader, endToken:S):MalReadResult
  newList:MalValue = MalMkValue($MAL_LIST_TYPE)
  currentToken:MalReader = MalNextToken(reader)
  ierror = 0

  while(strcmp(currentToken.peek, endToken) != 0 && ierror == 0) do
    if currentToken.done == 1 then
      newList = MalMkError(sprintf("expected '%s', got EOF", endToken))
      ierror = 1
    else
      next:MalReadResult = read_form(currentToken)
      nextValue:MalValue = MalReadResultValue(next)
      newList = MalAppendValue(newList, nextValue)
      currentToken = MalReadResultReader(next)

      if next.type == $MAL_ERROR_TYPE then
        ierror = 1
      endif
    endif
  od

  if ierror == 0 then
    currentToken = MalNextToken(currentToken)
  endif

  xout MalMkReadResult(newList, currentToken)

endop


opcode read_form(reader:MalReader):MalReadResult
  Stoken = reader.peek
  istrChar  = strchar:i(Stoken, 0)
  if strcmp("(", Stoken) == 0 then
    xout read_list(reader, ")")
  elseif strcmp("'", Stoken) == 0 then
    v:MalValue = MalMkValue($MAL_QUOTE_TYPE)
    reader = MalNextToken(reader)
    l:MalValue[] = v.list
    next:MalReadResult = read_form(reader)
    nextValue:MalValue = MalReadResultValue(next)
    l[0] = nextValue
    v.length = 1
    v.list = l
    ;; car:MalValue = l[0]
    ;; car = read_form(reader)
    xout MalMkReadResult(v, MalReadResultReader(next))
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
