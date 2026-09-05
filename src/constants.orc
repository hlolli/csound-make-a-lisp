;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

// identifier types
#define MAL_ERROR_TYPE #-1#
#define MAL_QUOTE_TYPE #1#
#define MAL_QUASI_QUOTE_TYPE #2#
#define MAL_UNQUOTE_TYPE #3#
#define MAL_SPLICE_QUOTE_TYPE #4#
#define MAL_WITH_META_TYPE #5#
#define MAL_DEREF_TYPE #6#
#define MAL_LIST_TYPE #7#
#define MAL_VECTOR_TYPE #8#
#define MAL_HASH_MAP_TYPE #9#
#define MAL_NUMBER_TYPE #10#
#define MAL_STRING_TYPE #11#
#define MAL_SYMBOL_TYPE #12#
#define MAL_KEYWORD_TYPE #13#
#define MAL_NIL_TYPE #14#
#define MAL_TRUE_TYPE #15#
#define MAL_FALSE_TYPE #16#
#define MAL_BUILTIN_TYPE #17#
#define MAL_BUILTIN_OPERATOR_TYPE #18#
#define MAL_BUILTIN_OPCODE_TYPE #19#
#define MAL_FUNCTION_TYPE #20#
#define MAL_ATOM_TYPE #21#
#define MAL_CSOUND_INSTRUMENT_TYPE #22#
#define MAL_CSOUND_NODE_TYPE #23#

// Csound graph node kinds
#define MAL_CSOUND_PARAM_NODE #1#
#define MAL_CSOUND_INFIX_NODE #2#
#define MAL_CSOUND_CALL_NODE #3#
#define MAL_CSOUND_ARRAY_NODE #4#
#define MAL_CSOUND_PROJECTION_NODE #5#
#define MAL_CSOUND_INDEX_NODE #6#

// input inbox
#define MAL_INPUT_EOF #-1#
#define MAL_INPUT_LINE #1#
#define MAL_INPUT_CAPACITY #16#

// tokens
#define MAL_TAB_TOKEN #9#
#define MAL_NEWLINE_TOKEN #10#
#define MAL_SPACE_TOKEN #32#
#define MAL_STAR_TOKEN #42#
#define MAL_PLUS_TOKEN #43#
#define MAL_COMMA_TOKEN #44#
#define MAL_MINUS_TOKEN #45#
#define MAL_PERIOD_TOKEN #46#
#define MAL_SLASH_TOKEN #47#
#define MAL_TILDE_TOKEN #126#
#define MAL_AT_TOKEN #64#
#define MAL_CURLY_OPEN_TOKEN #123#
#define MAL_CURLY_CLOSE_TOKEN #125#
#define MAL_BRACKET_OPEN_TOKEN #91#
#define MAL_BRACKET_CLOSE_TOKEN #93#
#define MAL_PAREN_OPEN_TOKEN #40#
#define MAL_PAREN_CLOSE_TOKEN #41#
#define MAL_SINGLE_QUOTE_TOKEN #39#
#define MAL_BACKTICK_TOKEN #96#
#define MAL_CARET_TOKEN #94#
#define MAL_DOUBLE_QUOTE_TOKEN #34#
#define MAL_BACKSLASH_TOKEN #92#
#define MAL_COLON_TOKEN #58#
#define MAL_SEMICOLON_TOKEN #59#

// error reason
#define MAL_ILLEGAL_TOKEN_ERROR #-1#
