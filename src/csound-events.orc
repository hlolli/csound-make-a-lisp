;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalScheduleCsoundInstrument(instrument:MalValue, args:MalValue, \
                                   start:i, duration:i):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)

  if (args.length > instrument.length) ithen
    result init MalMkError(sprintf( \
      "%s: expected at most %d arguments, got %d", \
      instrument.string, instrument.length, args.length))
  else
    scoreLine:S init sprintf("i \"%s\" %s %s", instrument.string, \
      MalCsoundNumber(start), MalCsoundNumber(duration))

    if (instrument.length > 0) ithen
      for index in [0 ... instrument.length - 1] do
        if (index < args.length) ithen
          argument:MalValue init MalAt(args, index)
        else
          argument init MalAt(instrument, index)
        endif

        if (argument.type != $MAL_NUMBER_TYPE) ithen
          result init MalMkError(sprintf( \
            "%s: instrument arguments must be numbers", instrument.string))
          break
        endif

        scoreArgument:S init sprintf(" %s", MalCsoundNumber(argument.number))
        scoreLine strcat scoreLine, scoreArgument
      od
    endif

    if (result.type != $MAL_ERROR_TYPE) ithen
      scoreline_i scoreLine
    endif
  endif

  xout result
endop

opcode MalCsoundEvent(args:MalValue):MalValue
  if (args.length < 1) ithen
    result:MalValue init MalMkError(sprintf( \
      "csound/event: expected event type and arguments, got %d arguments", \
      args.length))
  else
    eventType:MalValue init MalAt(args, 0)

    if (eventType.type != $MAL_STRING_TYPE) ithen
      result init MalMkError("csound/event: event type must be a string")
    elseif (strcmp(eventType.string, "i") == 0) ithen
      if (args.length < 4) ithen
        result init MalMkError( \
          "csound/event: instrument events need instrument, p2, and p3")
      else
        instrument:MalValue init MalAt(args, 1)
        start:MalValue init MalAt(args, 2)
        duration:MalValue init MalAt(args, 3)

        if (instrument.type != $MAL_CSOUND_INSTRUMENT_TYPE) ithen
          result init MalMkError( \
            "csound/event: expected a Csound instrument for an i event")
        elseif (start.type != $MAL_NUMBER_TYPE || \
                duration.type != $MAL_NUMBER_TYPE) ithen
          result init MalMkError("csound/event: p2 and p3 must be numbers")
        else
          instrumentArgs:MalValue init MalMkValue($MAL_LIST_TYPE)

          if (args.length > 4) ithen
            for index in [4 ... args.length - 1] do
              instrumentArgs init MalAppendValue(instrumentArgs, MalAt(args, index))
            od
          endif

          result init MalScheduleCsoundInstrument(instrument, instrumentArgs, \
            start.number, duration.number)
        endif
      endif
    elseif (strcmp(eventType.string, "f") == 0) ithen
      if (args.length < 5) ithen
        result init MalMkError("csound/event: table events need number, time, size, and GEN routine")
      else
        result init MalMkValue($MAL_NIL_TYPE)
        scoreLine:S init "f"
        for index in [1 ... args.length - 1] do
          argument:MalValue init MalAt(args, index)
          if (argument.type != $MAL_NUMBER_TYPE) ithen
            result init MalMkError("csound/event: table event arguments must be numbers")
            break
          endif
          scoreArgument:S init sprintf(" %s", MalCsoundNumber(argument.number))
          scoreLine strcat scoreLine, scoreArgument
        od
        if (result.type != $MAL_ERROR_TYPE) ithen
          scoreline_i scoreLine
        endif
      endif
    elseif (strcmp(eventType.string, "e") == 0) ithen
      if (args.length != 3) ithen
        result init MalMkError(sprintf( \
          "csound/event: e event expects 2 arguments, got %d", \
          args.length - 1))
      else
        endTime:MalValue init MalAt(args, 1)
        endDuration:MalValue init MalAt(args, 2)

        if (endTime.type != $MAL_NUMBER_TYPE || \
            endDuration.type != $MAL_NUMBER_TYPE) ithen
          result init MalMkError("csound/event: e event arguments must be numbers")
        else
          event_i "e", endTime.number, endDuration.number
          result init MalMkValue($MAL_NIL_TYPE)
        endif
      endif
    else
      result init MalMkError(sprintf("csound/event: unsupported event type '%s'", \
        eventType.string))
    endif
  endif

  xout result
endop

opcode MalCsoundEval(source:S):MalValue
  evaluated:i evalstr source
  xout MalMkNumber(evaluated)
endop
