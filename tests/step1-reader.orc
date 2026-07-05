#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop


opcode EVAL(ast:MalValue):MalValue
  xout ast
endop

opcode PRINT(ast:MalValue):S
  Sprintout = pr_str(ast)
  xout Sprintout
endop

opcode REP(input:S):S
  xout PRINT(EVAL(READ(input)))
endop

opcode REPL(input:S):void
  prints "AST: %s\n", REP(input)
endop

opcode ASSERT_REP(input:S, expected:S):void
  actual:S = REP(input)
  if (strcmp(actual, expected) == 0) then
    prints "REPL %s, Assertion success\n", input
  else
    prints "REPL %s, Assertion failed: expected '%s', got '%s'\n", input, expected, actual
    exitnow(1)
  endif
endop

instr TEST
  prints "Testing basic reader functionality\n"
  NumberAst:MalValue = READ("123")
  if (NumberAst.type == $MAL_NUMBER_TYPE && NumberAst.number == 123) then
    prints "READ number, Assertion success\n"
  else
    prints "READ number, Assertion failed: type=%d number=%f\n", NumberAst.type, NumberAst.number
    exitnow(1)
  endif

  NegativeNumberAst:MalValue = READ("-123")
  if (NegativeNumberAst.type == $MAL_NUMBER_TYPE && NegativeNumberAst.number == -123) then
    prints "READ negative number, Assertion success\n"
  else
    prints "READ negative number, Assertion failed: type=%d number=%f\n", \
      NegativeNumberAst.type, NegativeNumberAst.number
    exitnow(1)
  endif

  NilAst:MalValue = READ("nil")
  if (NilAst.type == $MAL_NIL_TYPE) then
    prints "READ nil, Assertion success\n"
  else
    prints "READ nil, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_NIL_TYPE, NilAst.type
    exitnow(1)
  endif

  TrueAst:MalValue = READ("true")
  if (TrueAst.type == $MAL_TRUE_TYPE) then
    prints "READ true, Assertion success\n"
  else
    prints "READ true, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_TRUE_TYPE, TrueAst.type
    exitnow(1)
  endif

  FalseAst:MalValue = READ("false")
  if (FalseAst.type == $MAL_FALSE_TYPE) then
    prints "READ false, Assertion success\n"
  else
    prints "READ false, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_FALSE_TYPE, FalseAst.type
    exitnow(1)
  endif

  SymbolAst:MalValue = READ("abc")
  if (SymbolAst.type != $MAL_SYMBOL_TYPE) then
    prints "READ symbol type, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_SYMBOL_TYPE, SymbolAst.type
    exitnow(1)
  elseif (strcmp(SymbolAst.string, "abc") != 0) then
    prints "READ symbol string, Assertion failed: expected 'abc', got '%s'\n", \
      SymbolAst.string
    exitnow(1)
  else
    prints "READ symbol, Assertion success\n"
  endif

  StringAst:MalValue = READ("\"hello world\"")
  if (StringAst.type != $MAL_STRING_TYPE) then
    prints "READ string type, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_STRING_TYPE, StringAst.type
    exitnow(1)
  elseif (strcmp(StringAst.string, "hello world") != 0) then
    prints "READ string value, Assertion failed: expected 'hello world', got '%s'\n", \
      StringAst.string
    exitnow(1)
  else
    prints "READ string, Assertion success\n"
  endif

  KeywordAst:MalValue = READ(":keyword")
  if (KeywordAst.type != $MAL_KEYWORD_TYPE) then
    prints "READ keyword type, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_KEYWORD_TYPE, KeywordAst.type
    exitnow(1)
  elseif (strcmp(KeywordAst.string, "keyword") != 0) then
    prints "READ keyword value, Assertion failed: expected 'keyword', got '%s'\n", \
      KeywordAst.string
    exitnow(1)
  else
    prints "READ keyword, Assertion success\n"
  endif

  QuoteAst:MalValue = READ("'(123 456)")
  if (QuoteAst.type == $MAL_QUOTE_TYPE && QuoteAst.length == 1) then
    ListAst:MalValue = QuoteAst.list[0]
    FirstAst:MalValue = ListAst.list[0]
    SecondAst:MalValue = ListAst.list[1]
    if (ListAst.type == $MAL_LIST_TYPE && ListAst.length == 2 && \
        FirstAst.number == 123 && SecondAst.number == 456) then
      prints "READ quote/list, Assertion success\n"
    else
      prints "READ quote/list, Assertion failed\n"
      exitnow(1)
    endif
  else
    prints "READ quote/list, Assertion failed\n"
    exitnow(1)
  endif

  QuasiQuoteAst:MalValue = READ("`abc")
  if (QuasiQuoteAst.type == $MAL_QUASI_QUOTE_TYPE && QuasiQuoteAst.length == 1) then
    QuasiQuoteValueAst:MalValue = QuasiQuoteAst.list[0]
    if (QuasiQuoteValueAst.type == $MAL_SYMBOL_TYPE && \
        strcmp(QuasiQuoteValueAst.string, "abc") == 0) then
      prints "READ quasiquote, Assertion success\n"
    else
      prints "READ quasiquote value, Assertion failed: type=%d string=%s\n", \
        QuasiQuoteValueAst.type, QuasiQuoteValueAst.string
      exitnow(1)
    endif
  else
    prints "READ quasiquote, Assertion failed: type=%d length=%d\n", \
      QuasiQuoteAst.type, QuasiQuoteAst.length
    exitnow(1)
  endif

  UnquoteAst:MalValue = READ("~abc")
  if (UnquoteAst.type == $MAL_UNQUOTE_TYPE && UnquoteAst.length == 1) then
    UnquoteValueAst:MalValue = UnquoteAst.list[0]
    if (UnquoteValueAst.type == $MAL_SYMBOL_TYPE && \
        strcmp(UnquoteValueAst.string, "abc") == 0) then
      prints "READ unquote, Assertion success\n"
    else
      prints "READ unquote value, Assertion failed: type=%d string=%s\n", \
        UnquoteValueAst.type, UnquoteValueAst.string
      exitnow(1)
    endif
  else
    prints "READ unquote, Assertion failed: type=%d length=%d\n", \
      UnquoteAst.type, UnquoteAst.length
    exitnow(1)
  endif

  SspliceQuote = sprintf("%c%c", $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
  SspliceQuoteInput = sprintf("%sabc", SspliceQuote)
  SpliceQuoteAst:MalValue = READ(SspliceQuoteInput)
  if (SpliceQuoteAst.type == $MAL_SPLICE_QUOTE_TYPE && SpliceQuoteAst.length == 1) then
    SpliceQuoteValueAst:MalValue = SpliceQuoteAst.list[0]
    if (SpliceQuoteValueAst.type == $MAL_SYMBOL_TYPE && \
        strcmp(SpliceQuoteValueAst.string, "abc") == 0) then
      prints "READ splice-unquote, Assertion success\n"
    else
      prints "READ splice-unquote value, Assertion failed: type=%d string=%s\n", \
        SpliceQuoteValueAst.type, SpliceQuoteValueAst.string
      exitnow(1)
    endif
  else
    prints "READ splice-unquote, Assertion failed: type=%d length=%d\n", \
      SpliceQuoteAst.type, SpliceQuoteAst.length
    exitnow(1)
  endif

  SderefInput = sprintf("%cabc", $MAL_AT_TOKEN)
  DerefAst:MalValue = READ(SderefInput)
  if (DerefAst.type == $MAL_DEREF_TYPE && DerefAst.length == 1) then
    DerefValueAst:MalValue = DerefAst.list[0]
    if (DerefValueAst.type == $MAL_SYMBOL_TYPE && \
        strcmp(DerefValueAst.string, "abc") == 0) then
      prints "READ deref, Assertion success\n"
    else
      prints "READ deref value, Assertion failed: type=%d string=%s\n", \
        DerefValueAst.type, DerefValueAst.string
      exitnow(1)
    endif
  else
    prints "READ deref, Assertion failed: type=%d length=%d\n", \
      DerefAst.type, DerefAst.length
    exitnow(1)
  endif

  WithMetaAst:MalValue = READ("^:private abc")
  if (WithMetaAst.type == $MAL_WITH_META_TYPE && WithMetaAst.length == 2) then
    WithMetaValueAst:MalValue = WithMetaAst.list[0]
    WithMetaMetaAst:MalValue = WithMetaAst.list[1]
    if (WithMetaValueAst.type == $MAL_SYMBOL_TYPE && \
        strcmp(WithMetaValueAst.string, "abc") == 0 && \
        WithMetaMetaAst.type == $MAL_KEYWORD_TYPE && \
        strcmp(WithMetaMetaAst.string, "private") == 0) then
      prints "READ with-meta, Assertion success\n"
    else
      prints "READ with-meta value, Assertion failed: value-type=%d value-string=%s meta-type=%d meta-string=%s\n", \
        WithMetaValueAst.type, WithMetaValueAst.string, WithMetaMetaAst.type, WithMetaMetaAst.string
      exitnow(1)
    endif
  else
    prints "READ with-meta, Assertion failed: type=%d length=%d\n", \
      WithMetaAst.type, WithMetaAst.length
    exitnow(1)
  endif

  ASSERT_REP("true", "true")
  ASSERT_REP("123", "123.00000")
  ASSERT_REP("-123", "-123.00000")
  ASSERT_REP("123 ", "123.00000")
  ASSERT_REP("abc", "abc")
  ASSERT_REP("abc", "abc")
  ASSERT_REP("abc ", "abc")
  ASSERT_REP("-", "-")
  ASSERT_REP("\"hello world\"", "\"hello world\"")
  ASSERT_REP("\"he\\\"llo\"", "\"he\\\"llo\"")
  ASSERT_REP("\"line\\nnext\"", "\"line\\nnext\"")
  ASSERT_REP(":keyword", ":keyword")
  ASSERT_REP("(nil :keyword abc)", "(nil :keyword abc)")
  ASSERT_REP("`abc", "`abc")
  ASSERT_REP("~abc", "~abc")
  ASSERT_REP(SspliceQuoteInput, SspliceQuoteInput)
  ASSERT_REP(SderefInput, SderefInput)
  ASSERT_REP("^:private abc", "^:private abc")
  SspliceQuoteList = sprintf("`(abc ~value %svalues)", SspliceQuote)
  ASSERT_REP(SspliceQuoteList, SspliceQuoteList)
  ASSERT_REP("(1 -2 3)", "(1.00000 -2.00000 3.00000)")
  ASSERT_REP("(1 (2 3) 4)", "(1.00000 (2.00000 3.00000) 4.00000)")
  REPL("'(123 456)")
  REPL("(nil true false abc)")
  ;; prints "SRES9: %s\n", SRES9
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
