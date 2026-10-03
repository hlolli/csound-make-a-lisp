;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Lower the Clojure forms to the MAL evaluator's single-body forms.
opcode MalBodyForms(ast:MalValue, start:i):MalValue
  result:MalValue init MalMkList1(MalMkSymbol("do"))
  if (ast.length > start) ithen
    for index in [start ... ast.length - 1] do
      result init MalAppendValue(result, MalAt(ast, index))
    od
  endif
  xout result
endop

opcode MalExpandFn(ast:MalValue, paramsIndex:i, name:S):MalValue
  result:MalValue init MalMkError(sprintf("%s: expected a parameter vector and body", name))
  if (ast.length > paramsIndex) ithen
    params:MalValue init MalAt(ast, paramsIndex)
    if (params.type != $MAL_VECTOR_TYPE) ithen
      result init MalMkError(sprintf("%s: params must be a vector", name))
    elseif (MalParamsAreValid(params) == 0) ithen
      result init MalMkError(sprintf("%s: params must be symbols with an optional & rest parameter", name))
    else
      valid:i = 1
      if (params.length > 0) ithen
        for index in [0 ... params.length - 1] do
          param:MalValue init MalAt(params, index)
          if (index > 0) ithen
            for previous in [0 ... index - 1] do
              other:MalValue init MalAt(params, previous)
              if (strcmp(param.string, other.string) == 0) ithen
                valid = 0
              endif
            od
          endif
        od
      endif
      if (valid == 0) ithen
        result init MalMkError(sprintf("%s: parameter names must be distinct", name))
      else
        result init MalMkList3(MalMkSymbol("fn*"), params, MalBodyForms(ast, paramsIndex + 1))
      endif
    endif
  endif
  xout result
endop

opcode MalEvalNamedDefinition(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  head:MalValue init MalAt(ast, 0)
  currentEnv:MalEnv init env
  result:MalValue init MalMkError(sprintf("%s: expected a name, parameter vector, and body", head.string))
  if (ast.length >= 3) ithen
    name:MalValue init MalAt(ast, 1)
    if (name.type != $MAL_SYMBOL_TYPE) ithen
      result init MalMkError(sprintf("%s: first argument must be a symbol", head.string))
    else
      functionForm:MalValue init MalExpandFn(ast, 2, head.string)
      if (functionForm.type == $MAL_ERROR_TYPE) ithen
        result init functionForm
      else
        definition:MalValue init MalMkList3(head, name, functionForm)
        result, currentEnv = MalEvalDefinition(definition, env, head.string, \
          MalIsSymbolNamed(head, "defmacro"), 1)
      endif
    endif
  endif
  xout result, currentEnv
endop

opcode MalLetBody(ast:MalValue):MalValue
  result:MalValue init MalMkError("let: expected a binding vector and body")
  if (ast.length >= 2) ithen
    bindings:MalValue init MalAt(ast, 1)
    if (bindings.type != $MAL_VECTOR_TYPE) ithen
      result init MalMkError("let: bindings must be a vector")
    elseif (bindings.length % 2 != 0) ithen
      result init MalMkError("let: bindings must contain even number of forms")
    else
      result init MalBodyForms(ast, 2)
      if (bindings.length > 0) ithen
        for index in [0 ... bindings.length / 2 - 1] do
          name:MalValue init MalAt(bindings, index * 2)
          if (name.type != $MAL_SYMBOL_TYPE) ithen
            result init MalMkError("let: binding name must be a symbol")
            break
          endif
        od
      endif
    endif
  endif
  xout result
endop
