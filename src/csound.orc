declare MalCsoundRenderValue(value:MalValue):(MalCsoundRender)
declare MalArityError(name:S, expected:i, actual:i):(MalValue)

opcode MalMkCsoundOpcode(name:S, kind:i, minArity:i, maxArity:i):MalValue
  opcodeValue:MalValue = MalMkValue($MAL_BUILTIN_OPCODE_TYPE)
  opcodeValue.string = name
  opcodeValue.number = kind
  opcodeValue = MalAppendValue(opcodeValue, MalMkNumber(minArity))
  opcodeValue = MalAppendValue(opcodeValue, MalMkNumber(maxArity))
  xout opcodeValue
endop

opcode MalMkCsoundNode(name:S, kind:i, args:MalValue):MalValue
  node:MalValue = MalMkValue($MAL_CSOUND_NODE_TYPE)
  node.string = name
  node.number = kind

  if (args.length > 0) then
    for index in [0 ... args.length - 1] do
      node = MalAppendValue(node, MalAt(args, index))
    od
  endif

  xout node
endop

opcode MalMkCsoundParam(index:i):MalValue
  emptyArgs:MalValue = MalMkValue($MAL_LIST_TYPE)
  node:MalValue = MalMkCsoundNode( \
    sprintf("p%d", index), $MAL_CSOUND_PARAM_NODE, emptyArgs)
  xout node
endop

opcode MalMkCsoundInfix(operator:S, args:MalValue):MalValue
  xout MalMkCsoundNode(operator, $MAL_CSOUND_INFIX_NODE, args)
endop

opcode MalMkCsoundInstrument(name:S, defaults:MalValue):MalValue
  instrument:MalValue = MalMkValue($MAL_CSOUND_INSTRUMENT_TYPE)
  instrument.string = name

  if (defaults.length > 0) then
    for index in [0 ... defaults.length - 1] do
      instrument = MalAppendValue(instrument, MalAt(defaults, index))
    od
  endif

  xout instrument
endop

opcode MalIsCsoundNode(value:MalValue):i
  valueType:i = value.type
  result:i = valueType == $MAL_CSOUND_NODE_TYPE
  xout result
endop

opcode MalCsoundOpcodeArity(fn:MalValue, args:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  if (fn.length != 2) then
    result = MalMkError(sprintf( \
      "%s: missing Csound opcode signature", fn.string))
  else
    minValue:MalValue = MalAt(fn, 0)
    maxValue:MalValue = MalAt(fn, 1)
    minArity:i = minValue.number
    maxArity:i = maxValue.number

    if (args.length < minArity || args.length > maxArity) then
      if (minArity == maxArity) then
        result = MalArityError(fn.string, minArity, args.length)
      else
        result = MalMkError(sprintf( \
          "%s: expected %d to %d arguments, got %d", \
          fn.string, minArity, maxArity, args.length))
      endif
    endif
  endif

  xout result
endop

opcode MalApplyCsoundOpcode(fn:MalValue, args:MalValue):MalValue
  result:MalValue = MalCsoundOpcodeArity(fn, args)

  if (result.type != $MAL_ERROR_TYPE) then
    result = MalMkCsoundNode(fn.string, fn.number, args)
  endif

  xout result
endop

opcode MalCsoundParamBindings(params:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_VECTOR_TYPE)

  if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) then
    result = MalMkError("definst: parameters must be a list or vector")
  elseif (params.length % 2 != 0) then
    result = MalMkError("definst: parameters must contain name/default pairs")
  else
    result = MalAppendValue(result, MalMkSymbol("p2"))
    result = MalAppendValue(result, MalMkCsoundParam(2))
    result = MalAppendValue(result, MalMkSymbol("p3"))
    result = MalAppendValue(result, MalMkCsoundParam(3))

    if (params.length > 0) then
      for index in [0 ... int(params.length / 2) - 1] do
        name:MalValue = MalAt(params, index * 2)
        defaultValue:MalValue = MalAt(params, index * 2 + 1)

        if (name.type != $MAL_SYMBOL_TYPE) then
          result = MalMkError("definst: parameter names must be symbols")
          break
        elseif (strcmp(name.string, "p2") == 0 || \
                strcmp(name.string, "p3") == 0) then
          result = MalMkError("definst: p2 and p3 are implicit parameters")
          break
        elseif (defaultValue.type != $MAL_NUMBER_TYPE) then
          result = MalMkError("definst: parameter defaults must be numbers")
          break
        else
          result = MalAppendValue(result, name)
          result = MalAppendValue(result, MalMkCsoundParam(index + 4))
        endif
      od
    endif
  endif

  xout result
endop

opcode MalCsoundIdentifierIsValid(value:MalValue):i
  valid:i = value.type == $MAL_SYMBOL_TYPE && strlen(value.string) > 0

  if (valid == 1) then
    for index in [0 ... strlen(value.string) - 1] do
      character:i = strchar:i(value.string, index)
      isLetter:i = (character >= 65 && character <= 90) || \
        (character >= 97 && character <= 122)
      isDigit:i = character >= 48 && character <= 57
      isUnderscore:i = character == 95

      if ((index == 0 && isLetter == 0 && isUnderscore == 0) || \
          (index > 0 && isLetter == 0 && isDigit == 0 && \
           isUnderscore == 0)) then
        valid = 0
        break
      endif
    od
  endif

  xout valid
endop

opcode MalCsoundAppendRender(aggregate:MalCsoundRender, \
                             child:MalCsoundRender):MalCsoundRender
  statements:S = aggregate.statements
  statements strcat statements, child.statements
  aggregate.statements = statements

  if (strlen(aggregate.error) == 0 && strlen(child.error) > 0) then
    aggregate.error = child.error
  endif

  xout aggregate
endop

opcode MalCsoundRenderArguments(node:MalValue, \
                                allowPairs:i):(MalCsoundRender)
  result:MalCsoundRender init "", "", 0, ""

  if (node.length > 0) then
    for index in [0 ... node.length - 1] do
      argument:MalCsoundRender = MalCsoundRenderValue(MalAt(node, index))
      result = MalCsoundAppendRender(result, argument)

      if (strlen(result.error) > 0) then
        break
      elseif (argument.outputs == 0) then
        result.error = sprintf( \
          "%s: statement cannot be used as an argument", node.string)
        break
      elseif (allowPairs == 0 && argument.outputs != 1) then
        result.error = sprintf( \
          "%s: expected a single-value argument", node.string)
        break
      else
        expression:S = result.expression

        if (strlen(result.expression) > 0) then
          expression strcat expression, ", "
        endif

        expression strcat expression, argument.expression
        result.expression = expression
        result.outputs += argument.outputs
      endif
    od
  endif

  xout result
endop

opcode MalCsoundRenderValue(value:MalValue):MalCsoundRender
  result:MalCsoundRender init "", "", 0, ""

  switch value.type
    case $MAL_NUMBER_TYPE
      result.expression = MalPrintNumber(value.number)
      result.outputs = 1

    case $MAL_CSOUND_NODE_TYPE
      switch value.number
        case $MAL_CSOUND_PARAM_NODE
          result.expression = value.string
          result.outputs = 1

        case $MAL_CSOUND_INFIX_NODE
          if (value.length != 2) then
            result.error = sprintf("%s: malformed Csound expression", \
              value.string)
          else
            left:MalCsoundRender = MalCsoundRenderValue(MalAt(value, 0))
            right:MalCsoundRender = MalCsoundRenderValue(MalAt(value, 1))
            result = MalCsoundAppendRender(result, left)
            result = MalCsoundAppendRender(result, right)

            if (strlen(result.error) == 0 && \
                (left.outputs != 1 || right.outputs != 1)) then
              result.error = sprintf( \
                "%s: expected single-value operands", value.string)
            elseif (strlen(result.error) == 0) then
              result.expression = sprintf("(%s %s %s)", \
                left.expression, value.string, right.expression)
              result.outputs = 1
            endif
          endif

        case $MAL_CSOUND_EXPRESSION_NODE
          arguments:MalCsoundRender = MalCsoundRenderArguments(value, 0)
          result = MalCsoundAppendRender(result, arguments)

          if (strlen(result.error) == 0) then
            result.expression = sprintf("%s(%s)", \
              value.string, arguments.expression)
            result.outputs = 1
          endif

        case $MAL_CSOUND_AUDIO_NODE
          arguments:MalCsoundRender = MalCsoundRenderArguments(value, 0)
          result = MalCsoundAppendRender(result, arguments)

          if (strlen(result.error) == 0) then
            variable:S = sprintf("aMal%d", malCsoundTemporaryCount)
            malCsoundTemporaryCount += 1
            statements:S = result.statements
            statement:S = sprintf("  %s %s %s\n", \
              variable, value.string, arguments.expression)
            statements strcat statements, statement
            result.statements = statements
            result.expression = variable
            result.outputs = 1
          endif

        case $MAL_CSOUND_AUDIO_PAIR_NODE
          arguments:MalCsoundRender = MalCsoundRenderArguments(value, 0)
          result = MalCsoundAppendRender(result, arguments)

          if (strlen(result.error) == 0) then
            leftVariable:S = sprintf("aMal%dL", malCsoundTemporaryCount)
            rightVariable:S = sprintf("aMal%dR", malCsoundTemporaryCount)
            malCsoundTemporaryCount += 1
            statements:S = result.statements
            statement:S = sprintf("  %s, %s %s %s\n", \
              leftVariable, rightVariable, value.string, arguments.expression)
            statements strcat statements, statement
            result.statements = statements
            result.expression = sprintf("%s, %s", \
              leftVariable, rightVariable)
            result.outputs = 2
          endif

        case $MAL_CSOUND_STATEMENT_NODE
          arguments:MalCsoundRender = MalCsoundRenderArguments(value, 1)
          result = MalCsoundAppendRender(result, arguments)

          if (strlen(result.error) == 0 && \
              strcmp(value.string, "outs") == 0 && \
              arguments.outputs != 2) then
            result.error = "outs: expected two audio outputs"
          elseif (strlen(result.error) == 0) then
            statements:S = result.statements
            statement:S = sprintf("  %s %s\n", \
              value.string, arguments.expression)
            statements strcat statements, statement
            result.statements = statements
          endif

        default
          result.error = sprintf("unknown Csound node '%s'", value.string)
      endsw

    default
      result.error = sprintf("cannot use %s in a Csound graph", pr_str(value))
  endsw

  xout result
endop

opcode MalCsoundDefaults(params:MalValue):MalValue
  defaults:MalValue = MalMkValue($MAL_LIST_TYPE)

  if (params.length > 0) then
    for index in [0 ... int(params.length / 2) - 1] do
      defaults = MalAppendValue(defaults, MalAt(params, index * 2 + 1))
    od
  endif

  xout defaults
endop

opcode MalCompileCsoundInstrument(name:MalValue, params:MalValue, \
                                  graph:MalValue):MalValue
  bindings:MalValue = MalCsoundParamBindings(params)

  if (MalCsoundIdentifierIsValid(name) == 0) then
    result:MalValue = MalMkError( \
      "definst: name must be a Csound-compatible symbol")
  elseif (bindings.type == $MAL_ERROR_TYPE) then
    result = bindings
  else
    malCsoundTemporaryCount = 0
    rendered:MalCsoundRender = MalCsoundRenderValue(graph)

    if (strlen(rendered.error) > 0) then
      result = MalMkError(rendered.error)
    elseif (rendered.outputs != 0) then
      result = MalMkError( \
        "definst: body must end in an output statement")
    else
      source:S = sprintf("instr %s\n%sendin\nreturn 1\n", \
        name.string, rendered.statements)
      compiled:i evalstr source

      if (compiled != 1) then
        result = MalMkError(sprintf( \
          "definst: Csound could not compile instrument '%s'", name.string))
      else
        defaults:MalValue = MalCsoundDefaults(params)
        result = MalMkCsoundInstrument(name.string, defaults)
      endif
    endif
  endif

  xout result
endop

opcode MalScheduleCsoundInstrument(instrument:MalValue, args:MalValue, \
                                   start:i, duration:i):MalValue
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  if (args.length > instrument.length) then
    result = MalMkError(sprintf( \
      "%s: expected at most %d arguments, got %d", \
      instrument.string, instrument.length, args.length))
  else
    scoreLine:S = sprintf("i \"%s\" %s %s", instrument.string, \
      MalPrintNumber(start), MalPrintNumber(duration))

    if (instrument.length > 0) then
      for index in [0 ... instrument.length - 1] do
        if (index < args.length) then
          argument:MalValue = MalAt(args, index)
        else
          argument = MalAt(instrument, index)
        endif

        if (argument.type != $MAL_NUMBER_TYPE) then
          result = MalMkError(sprintf( \
            "%s: instrument arguments must be numbers", instrument.string))
          break
        endif

        scoreArgument:S = sprintf(" %s", MalPrintNumber(argument.number))
        scoreLine strcat scoreLine, scoreArgument
      od
    endif

    if (result.type != $MAL_ERROR_TYPE) then
      scoreline_i scoreLine
    endif
  endif

  xout result
endop

opcode MalCsoundEvent(args:MalValue):MalValue
  if (args.length < 1) then
    result:MalValue = MalMkError(sprintf( \
      "csound/event: expected event type and arguments, got %d arguments", \
      args.length))
  else
    eventType:MalValue = MalAt(args, 0)

    if (eventType.type != $MAL_STRING_TYPE) then
      result = MalMkError("csound/event: event type must be a string")
    elseif (strcmp(eventType.string, "i") == 0) then
      if (args.length < 4) then
        result = MalMkError( \
          "csound/event: instrument events need instrument, p2, and p3")
      else
        instrument:MalValue = MalAt(args, 1)
        start:MalValue = MalAt(args, 2)
        duration:MalValue = MalAt(args, 3)

        if (instrument.type != $MAL_CSOUND_INSTRUMENT_TYPE) then
          result = MalMkError( \
            "csound/event: expected a Csound instrument for an i event")
        elseif (start.type != $MAL_NUMBER_TYPE || \
                duration.type != $MAL_NUMBER_TYPE) then
          result = MalMkError("csound/event: p2 and p3 must be numbers")
        else
          instrumentArgs:MalValue = MalMkValue($MAL_LIST_TYPE)

          if (args.length > 4) then
            for index in [4 ... args.length - 1] do
              instrumentArgs = MalAppendValue(instrumentArgs, MalAt(args, index))
            od
          endif

          result = MalScheduleCsoundInstrument(instrument, instrumentArgs, \
            start.number, duration.number)
        endif
      endif
    elseif (strcmp(eventType.string, "e") == 0) then
      if (args.length != 3) then
        result = MalMkError(sprintf( \
          "csound/event: e event expects 2 arguments, got %d", \
          args.length - 1))
      else
        endTime:MalValue = MalAt(args, 1)
        endDuration:MalValue = MalAt(args, 2)

        if (endTime.type != $MAL_NUMBER_TYPE || \
            endDuration.type != $MAL_NUMBER_TYPE) then
          result = MalMkError("csound/event: e event arguments must be numbers")
        else
          event_i "e", endTime.number, endDuration.number
          result = MalMkValue($MAL_NIL_TYPE)
        endif
      endif
    else
      result = MalMkError(sprintf("csound/event: unsupported event type '%s'", \
        eventType.string))
    endif
  endif

  xout result
endop

opcode MalCsoundEval(source:S):MalValue
  evaluated:i evalstr source
  xout MalMkNumber(evaluated)
endop
