;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalFreshLocal():MalValue
  malGensymCount += 1
  xout MalMkSymbol(sprintf("binding__%d#", malGensymCount))
endop

opcode MalBindingSymbol(value:MalValue):i
  result:i = value.type == $MAL_SYMBOL_TYPE && strcmp(value.string, "&") != 0
  xout result
endop

opcode MalBodyForms(ast:MalValue, start:i):MalValue
  result:MalValue init MalMkList1(MalMkSymbol("do"))
  if (ast.length > start) ithen
    for index in [start ... ast.length - 1] do
      result init MalAppendValue(result, MalAt(ast, index))
    od
  endif
  xout result
endop

declare MalExpandBinding(bindings:MalValue, pattern:MalValue, value:MalValue):MalValue

opcode MalExpandVectorBinding(bindings:MalValue, pattern:MalValue, source:MalValue):MalValue
  result:MalValue init bindings
  position:i = 0
  index:i = 0
  rest:i = 0
  while (index < pattern.length && result.type != $MAL_ERROR_TYPE) do
    item:MalValue init MalAt(pattern, index)
    if (item.type == $MAL_KEYWORD_TYPE && strcmp(item.string, "as") == 0) ithen
      if (index + 2 != pattern.length) ithen
        result init MalMkError("vector binding: :as must be followed by a final symbol")
      else
        name:MalValue init MalAt(pattern, index + 1)
        if (MalBindingSymbol(name) == 0) ithen
          result init MalMkError("vector binding: :as requires a symbol")
        else
          result init MalExpandBinding(result, name, source)
        endif
      endif
      index = pattern.length
    elseif (rest == 1) ithen
      result init MalMkError("vector binding: only :as may follow a rest binding")
    elseif (MalIsSymbolNamed(item, "&") == 1) ithen
      if (index + 1 >= pattern.length) ithen
        result init MalMkError("vector binding: missing binding after &")
      else
        name:MalValue init MalAt(pattern, index + 1)
        if (MalIsSymbolNamed(name, "&") == 1) ithen
          result init MalMkError("vector binding: expected a pattern after &")
        else
          tail:MalValue init MalMkList3(MalMkSymbol("clojure.core/drop"), MalMkNumber(position), source)
          result init MalExpandBinding(result, name, MalMkList2(MalMkSymbol("clojure.core/seq"), tail))
          rest = 1
          index += 2
        endif
      endif
    else
      lookup:MalValue init MalMkList3(MalMkSymbol("clojure.core/nth"), source, MalMkNumber(position))
      lookup init MalAppendValue(lookup, MalMkValue($MAL_NIL_TYPE))
      result init MalExpandBinding(result, item, lookup)
      index += 1
      position += 1
    endif
  od
  xout result
endop

opcode MalMapBindingLookup(source:MalValue, key:MalValue, name:MalValue, defaults:MalValue):MalValue
  result:MalValue init MalMkList3(MalMkSymbol("clojure.core/get"), source, key)
  defaultIndex:i = MalMapFindKey(defaults, name)
  if (defaultIndex >= 0) ithen
    result init MalAppendValue(result, MalAt(defaults, defaultIndex + 1))
  endif
  xout result
endop

opcode MalMapBindingSource(value:MalValue):MalValue
  if (value.type != $MAL_LIST_TYPE) ithen
    result:MalValue init value
  elseif (value.length == 1) ithen
    result init MalAt(value, 0)
  else
    result init MalNormalizeMap(value)
    if (value.length % 2 != 0) ithen
      trailing:MalValue init MalAt(value, value.length - 1)
      if (trailing.type == $MAL_HASH_MAP_TYPE) ithen
        result init MalAssocPairs(result, trailing, 0)
      elseif (trailing.type == $MAL_VECTOR_TYPE && trailing.length == 2) ithen
        result init MalMapAssoc(result, MalAt(trailing, 0), MalAt(trailing, 1))
      elseif (trailing.type != $MAL_NIL_TYPE) ithen
        result init MalMkError("map binding: expected key/value pairs with an optional final map")
      endif
    endif
  endif
  xout result
endop

opcode MalExpandMapBinding(bindings:MalValue, pattern:MalValue, source:MalValue):MalValue
  result:MalValue init bindings
  defaults:MalValue init MalMapGet(pattern, MalMkKeyword("or"))
  alias:MalValue init MalMapGet(pattern, MalMkKeyword("as"))
  hasDefaults:i = MalMapFindKey(pattern, MalMkKeyword("or")) >= 0
  hasAlias:i = MalMapFindKey(pattern, MalMkKeyword("as")) >= 0
  if (hasDefaults == 1 && defaults.type != $MAL_HASH_MAP_TYPE) ithen
    result init MalMkError("map binding: :or requires a map")
  elseif (hasAlias == 1 && MalBindingSymbol(alias) == 0) ithen
    result init MalMkError("map binding: :as requires a symbol")
  else
    if (hasAlias == 1) ithen
      result init MalExpandBinding(result, alias, source)
    endif
    index:i = 0
    while (index < pattern.length && result.type != $MAL_ERROR_TYPE) do
      item:MalValue init MalAt(pattern, index)
      key:MalValue init MalAt(pattern, index + 1)
      prefix:S, kind:S = MalNameParts(item.string)
      if (item.type == $MAL_KEYWORD_TYPE && \
          (strcmp(kind, "keys") == 0 || strcmp(kind, "strs") == 0 || strcmp(kind, "syms") == 0)) ithen
        if (key.type != $MAL_VECTOR_TYPE) ithen
          result init MalMkError("map binding: :keys, :strs, and :syms require a vector")
        elseif (key.length > 0) ithen
          for entry in [0 ... key.length - 1] do
            field:MalValue init MalAt(key, entry)
            if (field.type != $MAL_SYMBOL_TYPE && field.type != $MAL_KEYWORD_TYPE) ithen
              result init MalMkError("map binding: expected a field name")
              break
            endif
            fieldPrefix:S, local:S = MalNameParts(field.string)
            if (strlen(prefix) > 0) ithen
              fieldPrefix init prefix
            endif
            qualified:S init local
            if (strlen(fieldPrefix) > 0) ithen
              qualified init sprintf("%s/%s", fieldPrefix, local)
            endif
            name:MalValue init MalMkSymbol(local)
            if (strcmp(kind, "keys") == 0) ithen
              fieldKey:MalValue init MalMkKeyword(qualified)
            elseif (strcmp(kind, "strs") == 0) ithen
              fieldKey init MalMkString(qualified)
            else
              fieldKey init MalMkList2(MalMkSymbol("quote"), MalMkSymbol(qualified))
            endif
            result init MalExpandBinding(result, name, MalMapBindingLookup(source, fieldKey, name, defaults))
          od
        endif
      elseif (item.type != $MAL_KEYWORD_TYPE || \
          (strcmp(item.string, "as") != 0 && strcmp(item.string, "or") != 0)) ithen
        if (item.type == $MAL_SYMBOL_TYPE || item.type == $MAL_KEYWORD_TYPE) ithen
          item init MalMkSymbol(kind)
        endif
        result init MalExpandBinding(result, item, MalMapBindingLookup(source, key, item, defaults))
      endif
      index += 2
    od
  endif
  xout result
endop

opcode MalExpandBinding(bindings:MalValue, pattern:MalValue, value:MalValue):MalValue
  if (pattern.type == $MAL_SYMBOL_TYPE) ithen
    result:MalValue init MalAppendValue(MalAppendValue(bindings, pattern), value)
  elseif (pattern.type == $MAL_VECTOR_TYPE || pattern.type == $MAL_HASH_MAP_TYPE) ithen
    source:MalValue init MalFreshLocal()
    if (pattern.type == $MAL_HASH_MAP_TYPE) ithen
      value init MalMkList2(MalMkBuiltin("__mal-map-binding"), value)
    endif
    result init MalAppendValue(MalAppendValue(bindings, source), value)
    if (pattern.type == $MAL_VECTOR_TYPE) ithen
      result init MalExpandVectorBinding(result, pattern, source)
    else
      result init MalExpandMapBinding(result, pattern, source)
    endif
  else
    result init MalMkError("binding requires a symbol, vector, or map")
  endif
  xout result
endop

opcode MalExpandBindings(bindings:MalValue, name:S):MalValue
  if (bindings.type != $MAL_VECTOR_TYPE || bindings.length % 2 != 0) ithen
    result:MalValue init MalMkError(sprintf("%s: expected an even binding vector", name))
  else
    result init bindings
    index:i = 0
    while (index < bindings.length) do
      pattern:MalValue init MalAt(bindings, index)
      if (pattern.type != $MAL_SYMBOL_TYPE) ithen
        result init MalMkValue($MAL_VECTOR_TYPE)
        index = 0
        while (index < bindings.length && result.type != $MAL_ERROR_TYPE) do
          result init MalExpandBinding(result, MalAt(bindings, index), MalAt(bindings, index + 1))
          index += 2
        od
        break
      endif
      index += 2
    od
  endif
  xout result
endop

opcode MalExpandLet(ast:MalValue):MalValue
  if (ast.length < 2) ithen
    result:MalValue init MalMkError("let: expected a binding vector and body")
  else
    result init MalExpandBindings(MalAt(ast, 1), "let")
    if (result.type != $MAL_ERROR_TYPE) ithen
      result init MalMkList3(MalMkSymbol("let"), result, MalBodyForms(ast, 2))
    endif
  endif
  xout result
endop

opcode MalAddFunctionClause(definition:MalValue, params:MalValue, body:MalValue, name:S):MalValue
  if (params.type != $MAL_VECTOR_TYPE) ithen
    result:MalValue init MalMkError(sprintf("%s: params must be a vector", name))
  else
    raw:MalValue init MalMkValue($MAL_VECTOR_TYPE)
    bindings:MalValue init MalMkValue($MAL_VECTOR_TYPE)
    seen:MalValue init MalMkValue($MAL_VECTOR_TYPE)
    result init definition
    if (params.length > 0) ithen
      for index in [0 ... params.length - 1] do
        param:MalValue init MalAt(params, index)
        if (MalIsSymbolNamed(param, "&") == 1) ithen
          if (index != params.length - 2) ithen
            result init MalMkError(sprintf("%s: & must precede the final parameter", name))
            break
          endif
          raw init MalAppendValue(raw, param)
        else
          if (MalBindingSymbol(param) == 1) ithen
            argument:MalValue init param
          else
            argument init MalFreshLocal()
            bindings init MalExpandBinding(bindings, param, argument)
            if (bindings.type == $MAL_ERROR_TYPE) ithen
              result init bindings
              break
            endif
          endif
          duplicate:i = 0
          if (seen.length > 0) ithen
            for prior in [0 ... seen.length - 1] do
              if (MalEquals(MalAt(seen, prior), argument) == 1) ithen
                duplicate = 1
                break
              endif
            od
          endif
          if (duplicate == 1) ithen
            result init MalMkError(sprintf("%s: parameter names must be distinct", name))
            break
          endif
          raw init MalAppendValue(raw, argument)
          seen init MalAppendValue(seen, argument)
        endif
      od
    endif
    if (result.type != $MAL_ERROR_TYPE) ithen
      if (bindings.length > 0) ithen
        ;; The binding forms have already been checked and flattened.
        body init MalMkList3(MalMkSymbol("let"), bindings, body)
      endif
      result init MalAppendValue(MalAppendValue(result, raw), MalInternAst(body))
    endif
  endif
  xout result
endop

opcode MalClojureFn(ast:MalValue, env:MalEnv):MalValue
  definition:MalValue init MalMkValue($MAL_FUNCTION_TYPE)
  start:i = 1
  if (ast.length > 1) ithen
    candidate:MalValue init MalAt(ast, 1)
    if (MalBindingSymbol(candidate) == 1) ithen
      definition.string init candidate.string
      start += 1
    endif
  endif
  if (start >= ast.length) ithen
    definition init MalMkError("fn: expected a parameter vector or arity clauses")
  else
    firstClause:MalValue init MalAt(ast, start)
    if (firstClause.type == $MAL_VECTOR_TYPE) ithen
      definition init MalAddFunctionClause(definition, firstClause, MalBodyForms(ast, start + 1), "fn")
    else
      for index in [start ... ast.length - 1] do
        clause:MalValue init MalAt(ast, index)
        if (clause.type != $MAL_LIST_TYPE || clause.length == 0) ithen
          definition init MalMkError("fn: each arity clause starts with a parameter vector")
          break
        endif
        definition init MalAddFunctionClause(definition, MalAt(clause, 0), MalBodyForms(clause, 1), "fn")
        if (definition.type == $MAL_ERROR_TYPE) ithen
          break
        endif
      od
    endif
  endif
  if (definition.type != $MAL_ERROR_TYPE) ithen
    index:i = 0
    variadic:i = -1
    largest:i = -1
    while (index < definition.length && definition.type != $MAL_ERROR_TYPE) do
      params:MalValue init MalAt(definition, index)
      rest:i = MalRestParamIndex(params)
      if (rest >= 0) ithen
        if (variadic >= 0) ithen
          definition init MalMkError("fn: only one variadic arity is allowed")
        else
          variadic = rest
        endif
      else
        largest = max(largest, params.length)
        prior:i = 0
        while (prior < index) do
          other:MalValue init MalAt(definition, prior)
          if (MalRestParamIndex(other) < 0 && other.length == params.length) ithen
            definition init MalMkError("fn: duplicate arity")
            break
          endif
          prior += 2
        od
      endif
      index += 2
    od
    if (variadic >= 0 && largest > variadic && definition.type != $MAL_ERROR_TYPE) ithen
      definition init MalMkError("fn: fixed arity exceeds the variadic arity")
    endif
  endif

  if (definition.type == $MAL_ERROR_TYPE) ithen
    result:MalValue init definition
  else
    result init MalFunctionCaptureEnv(MalRegisterFunction(definition), env)
  endif
  xout result
endop

opcode MalExpandNamedDefinition(ast:MalValue):MalValue
  head:MalValue init MalAt(ast, 0)
  if (ast.length < 3) ithen
    result:MalValue init MalMkError(sprintf("%s: expected a name and parameters", head.string))
  else
    name:MalValue init MalAt(ast, 1)
    if (MalBindingSymbol(name) == 0) ithen
      result init MalMkError(sprintf("%s: first argument must be a symbol", head.string))
    else
      functionForm:MalValue init MalMkList1(MalMkSymbol("fn"))
      for index in [2 ... ast.length - 1] do
        functionForm init MalAppendValue(functionForm, MalAt(ast, index))
      od
      result init MalMkList3(head, name, functionForm)
    endif
  endif
  xout result
endop

opcode MalEvalNamedDefinition(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  head:MalValue init MalAt(ast, 0)
  definition:MalValue init MalExpandNamedDefinition(ast)
  currentEnv:MalEnv init MalEnvHandle(env.id)
  if (definition.type == $MAL_ERROR_TYPE) ithen
    result:MalValue init definition
  else
    result, currentEnv = MalEvalDefinition(definition, env, head.string, MalIsSymbolNamed(head, "defmacro"), 1)
  endif
  xout result, currentEnv
endop
