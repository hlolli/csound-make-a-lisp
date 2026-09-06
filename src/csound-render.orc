;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalCsoundAppendRender(aggregate:MalCsoundRender, child:MalCsoundRender):MalCsoundRender
  text:S init aggregate.statements
  text strcat text, child.statements
  aggregate.statements init text
  if (strlen(aggregate.error) == 0 && strlen(child.error) > 0) ithen
    aggregate.error init child.error
  endif
  xout aggregate
endop

opcode MalCsoundCachePut(identity:i, rendered:MalCsoundRender):void
  capacity:i = lenarray(malCsoundCacheIds)
  if (malCsoundCacheCount >= capacity) ithen
    savedIds:i[] init malCsoundCacheCount
    savedValues:MalCsoundRender[] init malCsoundCacheCount
    if (malCsoundCacheCount > 0) ithen
      for index in [0 ... malCsoundCacheCount - 1] do
        savedIds[index] = malCsoundCacheIds[index]
        savedValues[index] init malCsoundCacheValues[index]
      od
    endif
    newCapacity:i = capacity == 0 ? 32 : capacity * 2
    malCsoundCacheIds init newCapacity
    malCsoundCacheValues init newCapacity
    if (malCsoundCacheCount > 0) ithen
      for index in [0 ... malCsoundCacheCount - 1] do
        malCsoundCacheIds[index] = savedIds[index]
        malCsoundCacheValues[index] init savedValues[index]
      od
    endif
  endif
  malCsoundCacheIds[malCsoundCacheCount] = identity
  malCsoundCacheValues[malCsoundCacheCount] init rendered
  malCsoundCacheCount += 1
endop

opcode MalCsoundRenderValue(value:MalValue):MalCsoundRender
  result:MalCsoundRender init "", "", 0, ""
  cached:i = 0
  if (value.type == $MAL_NUMBER_TYPE) ithen
    result.expression init MalPrintNumber(value.number)
    result.outputs = 1
  elseif (value.type == $MAL_STRING_TYPE) ithen
    result.expression init pr_str_with_readability(value, 1)
    result.outputs = 1
  elseif (value.type != $MAL_CSOUND_NODE_TYPE) ithen
    result.error init sprintf("cannot use %s in a Csound graph", pr_str(value))
  else
    identity:MalValue init MalAt(value, 1)
    if (malCsoundCacheCount > 0) ithen
      for cacheIndex in [0 ... malCsoundCacheCount - 1] do
        if (malCsoundCacheIds[cacheIndex] == identity.number) ithen
          result init malCsoundCacheValues[cacheIndex]
          result.statements init ""
          cached = 1
          break
        endif
      od
    endif
    if (cached == 0) ithen
      types:S[] init MalCsoundTypeList(MalCsoundTypes(value))
      result.outputs = lenarray(types)
      if (value.number == $MAL_CSOUND_PARAM_NODE) ithen
        result.expression init value.string
      elseif (value.number == $MAL_CSOUND_PROJECTION_NODE) ithen
        parent:MalCsoundRender init MalCsoundRenderValue(MalAt(value, 2))
        result init MalCsoundAppendRender(result, parent)
        outputExpressions:S[] init MalCsoundTypeList(parent.expression)
        projectionIndex:MalValue init MalAt(value, 3)
        outputIndex:i = projectionIndex.number
        outputExpression:S init outputExpressions[outputIndex]
        result.expression init outputExpression
      elseif (value.number == $MAL_CSOUND_INFIX_NODE || \
              value.number == $MAL_CSOUND_INDEX_NODE) ithen
        left:MalCsoundRender init MalCsoundRenderValue(MalAt(value, 2))
        right:MalCsoundRender init MalCsoundRenderValue(MalAt(value, 3))
        result init MalCsoundAppendRender(result, left)
        result init MalCsoundAppendRender(result, right)
        if (value.number == $MAL_CSOUND_INFIX_NODE) ithen
          result.expression init sprintf("(%s %s %s)", left.expression, value.string, right.expression)
        else
          result.expression init sprintf("%s[%s]", left.expression, right.expression)
        endif
      elseif (value.number == $MAL_CSOUND_ARRAY_NODE) ithen
        variable:S init sprintf("%sMal%d", strsub(types[0], 0, 1), malCsoundTemporaryCount)
        malCsoundTemporaryCount += 1
        statement:S init sprintf("  %s[] init %d\n", variable, value.length - 2)
        result.statements init statement
        if (value.length > 2) ithen
          for index in [2 ... value.length - 1] do
            child:MalCsoundRender init MalCsoundRenderValue(MalAt(value, index))
            result init MalCsoundAppendRender(result, child)
            statement init sprintf("  %s[%d] = %s\n", variable, index - 2, child.expression)
            result.statements strcat result.statements, statement
          od
        endif
        result.expression init variable
      elseif (value.number == $MAL_CSOUND_CALL_NODE) ithen
        arguments:S init ""
        if (value.length > 2) ithen
          for index in [2 ... value.length - 1] do
            child:MalCsoundRender init MalCsoundRenderValue(MalAt(value, index))
            result init MalCsoundAppendRender(result, child)
            if (index > 2) ithen
              arguments strcat arguments, ", "
            endif
            arguments strcat arguments, child.expression
          od
        endif
        declarations:S init ""
        expressions:S init ""
        if (lenarray(types) > 0) ithen
          for index in [0 ... lenarray(types) - 1] do
            variable:S init sprintf("%sMal%d", strsub(types[index], 0, 1), malCsoundTemporaryCount)
            malCsoundTemporaryCount += 1
            if (index > 0) ithen
              declarations strcat declarations, ", "
              expressions strcat expressions, ","
            endif
            expressions strcat expressions, variable
            declarations strcat declarations, variable
            declarations strcat declarations, strsub(types[index], 1)
          od
          declarations strcat declarations, " "
        endif
        ;; Scalar math functions need expression syntax. The explicit type
        ;; keeps the output signature selected by MAL when inputs can promote.
        scalarType:S init ""
        if (lenarray(types) == 1) ithen
          scalarType init types[0]
        endif
        if (strlen(scalarType) == 1) ithen
          statement:S init sprintf("  %s = %s:%s(%s)\n", \
            expressions, value.string, scalarType, arguments)
        else
          statement init sprintf("  %s%s %s\n", declarations, value.string, arguments)
        endif
        result.statements strcat result.statements, statement
        result.expression init expressions
      else
        result.error init "unknown Csound graph node"
      endif
      MalCsoundCachePut(identity.number, result)
    endif
  endif
  xout result
endop

opcode MalCsoundInstrumentSource(name:MalValue, params:MalValue, graph:MalValue):MalValue
  bindings:MalValue init MalCsoundParamBindings(params)
  if (MalCsoundIdentifierIsValid(name) == 0) ithen
    result:MalValue init MalMkError("csound/definst: name must be a Csound-compatible symbol")
  elseif (bindings.type == $MAL_ERROR_TYPE) ithen
    result init bindings
  elseif (graph.type == $MAL_ERROR_TYPE) ithen
    result init graph
  else
    malCsoundTemporaryCount = 0
    malCsoundCacheCount = 0
    rendered:MalCsoundRender init MalCsoundRenderValue(graph)
    ;; The cache belongs to this render only; don't keep old graph strings alive.
    malCsoundCacheIds init 0
    malCsoundCacheValues init 0
    malCsoundCacheCount = 0
    if (strlen(rendered.error) > 0) ithen
      result init MalMkError(rendered.error)
    elseif (rendered.outputs != 0) ithen
      result init MalMkError("csound/definst: body must end in an output statement")
    else
      result init MalMkString(sprintf("instr %s\n%sendin\nreturn 1\n", name.string, rendered.statements))
    endif
  endif
  xout result
endop

opcode MalCompileCsoundInstrument(name:MalValue, params:MalValue, graph:MalValue):MalValue
  source:MalValue init MalCsoundInstrumentSource(name, params, graph)
  if (source.type == $MAL_ERROR_TYPE) ithen
    result:MalValue init source
  else
    compiled:i evalstr source.string
    if (compiled != 1) ithen
      result init MalMkError(sprintf("csound/definst: Csound could not compile instrument '%s'", name.string))
    else
      result init MalMkCsoundInstrument(name.string, MalCsoundDefaults(params))
    endif
  endif
  xout result
endop
