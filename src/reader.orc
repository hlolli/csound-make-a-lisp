;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

declare read_form(reader:MalReader):(MalReadResult)

opcode isCharWordBoundry(char:i):i
  ires = 0
  if (char == $MAL_NEWLINE_TOKEN || \
      char == $MAL_SPACE_TOKEN || \
      char == $MAL_TAB_TOKEN || \
      char == $MAL_COMMA_TOKEN || \
      char == $MAL_SEMICOLON_TOKEN || \
      char == $MAL_DOUBLE_QUOTE_TOKEN || \
      char == $MAL_PAREN_OPEN_TOKEN || \
      char == $MAL_PAREN_CLOSE_TOKEN || \
      char == $MAL_CURLY_OPEN_TOKEN || \
      char == $MAL_CURLY_CLOSE_TOKEN  || \
      char == $MAL_BRACKET_OPEN_TOKEN  || \
      char == $MAL_BRACKET_CLOSE_TOKEN) \
      ithen
    ires = 1
  endif
  xout(ires)
endop

opcode nextWordBoundry(input:S, from:i, maxLookahead:i):i
  indx = from
  ifound = 0
  while (indx < maxLookahead && ifound == 0) do
    ipeek = strchar:i(input, indx)
    if (isCharWordBoundry(ipeek) == 1) ithen
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
    if (ipeek == $MAL_NEWLINE_TOKEN) ithen
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

    if (iescaped == 1) ithen
      iescaped = 0
      indx += 1
    elseif (ipeek == $MAL_BACKSLASH_TOKEN) ithen
      iescaped = 1
      indx += 1
    elseif (ipeek == $MAL_DOUBLE_QUOTE_TOKEN) ithen
      ifound = indx + 1
    else
      indx += 1
    endif
  od

  xout(ifound == 0 ? maxLookahead : ifound)
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
    if (ipeek == $MAL_SPACE_TOKEN || ipeek == $MAL_TAB_TOKEN || \
        ipeek == $MAL_COMMA_TOKEN || ipeek == $MAL_NEWLINE_TOKEN) ithen
      indx += 1
      igoto END
    endif

    ;; jump over line comments
    if (ipeek == $MAL_SEMICOLON_TOKEN) ithen
      inextNewline = nextEndOfLine(input, indx, istrLen)
      indx = inextNewline
      igoto END
    endif

    ;; test for ~@ token
    if (ipeek == $MAL_TILDE_TOKEN && ipeek2 == $MAL_AT_TOKEN) ithen
      STokens[itokenCnt] init strcpy(strsub(input, indx, indx + 2))
      itokenCnt += 1
      indx += 2
      igoto END
    endif

    ;; capture strings, including escaped quotes and unterminated strings
    if (ipeek == $MAL_DOUBLE_QUOTE_TOKEN) ithen
      inextString = nextStringTokenDelimiter(input, indx, istrLen)
      STokens[itokenCnt] init strcpy(strsub(input, indx, inextString))
      itokenCnt += 1
      indx = inextString
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
        ipeek == $MAL_CARET_TOKEN) ithen
      STokens[itokenCnt] init strcpy(strsub(input, indx, indx + 1))
      itokenCnt += 1
      indx += 1
      igoto END
    endif

    ;; default case: capture delimited tokens (symbols)
    inextBoundry = nextWordBoundry(input, indx, istrLen)
    SNext init strsub(input, indx, inextBoundry)
    ;; prints "SNext %s %d\n", SNext, itokenCnt
    STokens[itokenCnt] init SNext
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
  Sout init ""

  while (indx < itokenLen - 1) do
    ichar = strchar:i(token, indx)

    if (ichar == $MAL_BACKSLASH_TOKEN && indx + 1 < itokenLen - 1) ithen
      inext = strchar:i(token, indx + 1)

      if (inext == 110) ithen
        Schar init sprintf("%c", $MAL_NEWLINE_TOKEN)
      else
        Schar init sprintf("%c", inext)
      endif

      Sout strcat Sout, Schar
      indx += 2
    else
      Schar init sprintf("%c", ichar)
      Sout strcat Sout, Schar
      indx += 1
    endif
  od

  xout Sout
endop

opcode MalStringTokenHasClosingQuote(token:S):i
  itokenLen = strlen(token)
  ires = 0

  if (itokenLen >= 2 && \
      strchar:i(token, 0) == $MAL_DOUBLE_QUOTE_TOKEN && \
      strchar:i(token, itokenLen - 1) == $MAL_DOUBLE_QUOTE_TOKEN) ithen
    ibackslashCount = 0
    indx = itokenLen - 2

    while (indx > 0 && strchar:i(token, indx) == $MAL_BACKSLASH_TOKEN) do
      ibackslashCount += 1
      indx -= 1
    od

    ires = ibackslashCount % 2 == 0
  endif

  xout ires
endop


opcode read_atom(reader:MalReader):MalValue
  Stoken init reader.peek
  itokenLen = strlen(Stoken)
  ifirstChar = strchar:i(Stoken, 0)

  if (ifirstChar == $MAL_DOUBLE_QUOTE_TOKEN && \
      MalStringTokenHasClosingQuote(Stoken) == 0) ithen
    v:MalValue init MalMkError("expected '\"', got EOF")
  elseif (ifirstChar == $MAL_DOUBLE_QUOTE_TOKEN) ithen
    v:MalValue init MalMkString(MalDecodeStringToken(Stoken))
  elseif (ifirstChar == $MAL_COLON_TOKEN) ithen
    v:MalValue init MalMkKeyword(strsub(Stoken, 1, itokenLen))
  elseif MalIsNumericString(Stoken) == 1 ithen
    inum = strtod:i(Stoken)
    v:MalValue init MalMkNumber(inum)
  elseif strcmp("nil", Stoken) == 0 ithen
    v:MalValue init MalMkValue($MAL_NIL_TYPE)
  elseif strcmp("true", Stoken) == 0 ithen
    v:MalValue init MalMkValue($MAL_TRUE_TYPE)
  elseif strcmp("false", Stoken) == 0 ithen
    v:MalValue init MalMkValue($MAL_FALSE_TYPE)
  else
    v:MalValue init MalMkSymbol(Stoken)
  endif

  xout v
endop

opcode read_sequence(reader:MalReader, endToken:S, sequenceType:i):MalReadResult
  newSequence:MalValue init MalMkValue(sequenceType)
  currentToken:MalReader init MalNextToken(reader)
  ierror = 0
  ifoundEnd = 0

  while(ifoundEnd == 0 && ierror == 0) do
    if currentToken.done == 1 ithen
      newSequence init MalMkError(sprintf("expected '%s', got EOF", endToken))
      ierror = 1
    elseif strcmp(currentToken.peek, endToken) == 0 ithen
      ifoundEnd = 1
    else
      next:MalReadResult init read_form(currentToken)
      nextValue:MalValue init MalReadResultValue(next)
      currentToken init MalReadResultReader(next)

      if nextValue.type == $MAL_ERROR_TYPE ithen
        newSequence init nextValue
        ierror = 1
      else
        newSequence init MalAppendValue(newSequence, nextValue)
      endif
    endif
  od

  if ierror == 0 ithen
    currentToken init MalNextToken(currentToken)
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
  result:MalReadResult init read_sequence(reader, endToken, $MAL_HASH_MAP_TYPE)
  value:MalValue init MalReadResultValue(result)

  if (value.type != $MAL_ERROR_TYPE && value.length % 2 != 0) ithen
    value init MalMkError("expected hash-map value, got end of map")
    result init MalMkReadResult(value, MalReadResultReader(result))
  elseif (value.type != $MAL_ERROR_TYPE) ithen
    value init MalNormalizeMap(value)
    result init MalMkReadResult(value, MalReadResultReader(result))
  endif

  xout result
endop

opcode read_reader_macro(reader:MalReader, macroSymbol:S, macroToken:S):MalReadResult
  v:MalValue init MalMkValue($MAL_LIST_TYPE)
  result:MalReadResult init MalMkReadResult(v, reader)
  reader init MalNextToken(reader)

  if reader.done == 1 ithen
    v init MalMkError(sprintf("expected form after '%s', got EOF", macroToken))
    result init MalMkReadResult(v, reader)
  else
    next:MalReadResult init read_form(reader)
    nextValue:MalValue init MalReadResultValue(next)
    if nextValue.type == $MAL_ERROR_TYPE ithen
      result init next
    else
      v init MalMkList2(MalMkSymbol(macroSymbol), nextValue)
      result init MalMkReadResult(v, MalReadResultReader(next))
    endif
  endif

  xout result
endop

opcode read_with_meta(reader:MalReader):MalReadResult
  v:MalValue init MalMkValue($MAL_LIST_TYPE)
  result:MalReadResult init MalMkReadResult(v, reader)
  reader init MalNextToken(reader)

  if reader.done == 1 ithen
    v init MalMkError("expected metadata after '^', got EOF")
    result init MalMkReadResult(v, reader)
  else
    meta:MalReadResult init read_form(reader)
    metaValue:MalValue init MalReadResultValue(meta)
    formReader:MalReader init MalReadResultReader(meta)

    if (metaValue.type == $MAL_ERROR_TYPE) ithen
      result init meta
    elseif formReader.done == 1 ithen
      v init MalMkError("expected form after '^' metadata, got EOF")
      result init MalMkReadResult(v, formReader)
    else
      form:MalReadResult init read_form(formReader)
      formValue:MalValue init MalReadResultValue(form)
      if formValue.type == $MAL_ERROR_TYPE ithen
        result init form
      else
        v init MalMkList3(MalMkSymbol("with-meta"), formValue, metaValue)
        result init MalMkReadResult(v, MalReadResultReader(form))
      endif
    endif
  endif

  xout result
endop


opcode read_form(reader:MalReader):MalReadResult
  Stoken init reader.peek
  itokenLen = strlen(Stoken)
  istrChar  = strchar:i(Stoken, 0)
  v:MalValue init MalMkError("internal read_form dispatch error")
  result:MalReadResult init MalMkReadResult(v, reader)

  switch istrChar
    case $MAL_PAREN_OPEN_TOKEN
      result init read_list(reader, ")")

    case $MAL_BRACKET_OPEN_TOKEN
      result init read_vector(reader, "]")

    case $MAL_CURLY_OPEN_TOKEN
      result init read_hash_map(reader, "}")

    case $MAL_PAREN_CLOSE_TOKEN
      v init MalMkError("unexpected ')'")
      result init MalMkReadResult(v, MalNextToken(reader))

    case $MAL_BRACKET_CLOSE_TOKEN
      v init MalMkError("unexpected ']'")
      result init MalMkReadResult(v, MalNextToken(reader))

    case $MAL_CURLY_CLOSE_TOKEN
      v init MalMkError("unexpected '}'")
      result init MalMkReadResult(v, MalNextToken(reader))

    case $MAL_SINGLE_QUOTE_TOKEN
      result init read_reader_macro(reader, "quote", "'")

    case $MAL_BACKTICK_TOKEN
      result init read_reader_macro(reader, "quasiquote", "`")

    case $MAL_TILDE_TOKEN
      if (itokenLen == 2 && strchar:i(Stoken, 1) == $MAL_AT_TOKEN) ithen
        SspliceQuote init sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
        result init read_reader_macro(reader, "splice-unquote", SspliceQuote)
      else
        result init read_reader_macro(reader, "unquote", "~")
      endif

    case $MAL_AT_TOKEN
      Sderef init sprintf("%c", $MAL_AT_TOKEN)
      result init read_reader_macro(reader, "deref", Sderef)

    case $MAL_CARET_TOKEN
      result init read_with_meta(reader)

    default
      v init read_atom(reader)
      result init MalMkReadResult(v, MalNextToken(reader))
  endsw

  xout result
endop

opcode read_str(input:S):MalValue
  tstruct:MalTokens init tokenize(input)
  returnValue:MalValue init MalMkValue($MAL_NIL_TYPE)

  if (tstruct.length > 0) ithen
    reader:MalReader init MalMkReader(tstruct)
    result:MalReadResult init read_form(reader)
    returnValue init MalReadResultValue(result)
  endif

  xout returnValue
endop
