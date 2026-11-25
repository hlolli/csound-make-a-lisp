;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalSpecialForm4(name:S, first:MalValue, second:MalValue, third:MalValue):MalValue
  result:MalValue init MalMkList3(MalMkSymbol(name), first, second)
  xout MalAppendValue(result, third)
endop

opcode MalExpandLoop(args:MalValue):MalValue
  result:MalValue init MalMkError("loop: expected an even binding vector")
  if (args.length > 0) ithen
    bindings:MalValue init MalAt(args, 0)
    if (bindings.type == $MAL_VECTOR_TYPE && bindings.length % 2 == 0) ithen
      initial:MalValue init MalMkValue($MAL_VECTOR_TYPE)
      params:MalValue init MalMkValue($MAL_VECTOR_TYPE)
      iteration:MalValue init MalMkValue($MAL_VECTOR_TYPE)
      functionName:MalValue init MalFreshLocal()
      call:MalValue init MalMkList1(functionName)
      index:i = 0
      while (index < bindings.length) do
        pattern:MalValue init MalAt(bindings, index)
        source:MalValue init MalAt(bindings, index + 1)
        ;; Preserve each original value for the first iteration, even when a
        ;; later initializer shadows a name in this binding's pattern.
        argument:MalValue init MalFreshLocal()
        initial init MalAppendValue(MalAppendValue(initial, argument), source)
        initial init MalAppendValue(MalAppendValue(initial, pattern), argument)
        params init MalAppendValue(params, argument)
        call init MalAppendValue(call, argument)
        iteration init MalAppendValue(MalAppendValue(iteration, pattern), argument)
        index += 2
      od
      body:MalValue init MalMkList3(MalMkSymbol("let"), iteration, MalBodyForms(args, 1))
      function:MalValue init MalMkList3(MalMkSymbol("fn"), params, body)
      ;; Create the closure before the initializer scopes. It only needs the
      ;; outer lexical scope and the current iteration's parameters.
      wrapper:MalValue init MalMkValue($MAL_VECTOR_TYPE)
      wrapper init MalAppendValue(MalAppendValue(wrapper, functionName), function)
      result init MalMkList3(MalMkSymbol("let"), wrapper, MalMkList3(MalMkSymbol("let"), initial, call))
    endif
  endif
  xout result
endop

opcode MalIterationStep(index:MalValue, end:MalValue, body:MalValue):MalValue
  nil:MalValue init MalMkValue($MAL_NIL_TYPE)
  bindings:MalValue init MalMkValue($MAL_VECTOR_TYPE)
  bindings init MalAppendValue(MalAppendValue(bindings, index), MalMkNumber(0))
  test:MalValue init MalMkList3(MalMkSymbol("clojure.core/<"), index, end)
  xout MalExpandLoop(MalMkList2(bindings, MalSpecialForm4("if", test, body, nil)))
endop

opcode MalIterationRecur(index:MalValue):MalValue
  xout MalMkList2(MalMkSymbol("recur"), MalMkList2(MalMkSymbol("clojure.core/inc"), index))
endop

opcode MalExpandDotimes(args:MalValue):MalValue
  result:MalValue init MalMkError("dotimes: expected [name count] and body")
  if (args.length > 0) ithen
    spec:MalValue init MalAt(args, 0)
    if (spec.type == $MAL_VECTOR_TYPE && spec.length == 2) ithen
      index:MalValue init MalAt(spec, 0)
      if (MalBindingSymbol(index) == 1) ithen
        end:MalValue init MalFreshLocal()
        size:MalValue init MalMkList3(MalMkSymbol("clojure.core/quot"), MalAt(spec, 1), MalMkNumber(1))
        bindings:MalValue init MalMkValue($MAL_VECTOR_TYPE)
        bindings init MalAppendValue(MalAppendValue(bindings, end), size)
        body:MalValue init MalMkList3(MalMkSymbol("do"), MalBodyForms(args, 1), MalIterationRecur(index))
        result init MalMkList3(MalMkSymbol("let"), bindings, MalIterationStep(index, end, body))
      endif
    endif
  endif
  xout result
endop

opcode MalExpandDoseqBody(bindings:MalValue, offset:i, body:MalValue, again:MalValue):MalValue
  nil:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (offset == bindings.length) ithen
    result:MalValue init MalMkList3(MalMkSymbol("do"), body, again)
  else
    pattern:MalValue init MalAt(bindings, offset)
    source:MalValue init MalAt(bindings, offset + 1)
    if (pattern.type == $MAL_KEYWORD_TYPE) ithen
      if (again.type == $MAL_NIL_TYPE) ithen
        result init MalMkError("doseq: a modifier must follow a binding")
      else
        nested:MalValue init MalExpandDoseqBody(bindings, offset + 2, body, again)
        if (nested.type == $MAL_ERROR_TYPE) ithen
          result init nested
        elseif (strcmp(pattern.string, "let") == 0) ithen
          result init MalMkList3(MalMkSymbol("let"), source, nested)
        elseif (strcmp(pattern.string, "when") == 0) ithen
          result init MalSpecialForm4("if", source, nested, again)
        elseif (strcmp(pattern.string, "while") == 0) ithen
          result init MalSpecialForm4("if", source, nested, nil)
        else
          result init MalMkError(sprintf("doseq: unknown modifier :%s", pattern.string))
        endif
      endif
    else
      index:MalValue init MalFreshLocal()
      nested init MalExpandDoseqBody(bindings, offset + 2, body, MalIterationRecur(index))
      if (nested.type == $MAL_ERROR_TYPE) ithen
        result init nested
      else
        items:MalValue init MalFreshLocal()
        size:MalValue init MalFreshLocal()
        sourceBindings:MalValue init MalMkValue($MAL_VECTOR_TYPE)
        sourceBindings init MalAppendValue(MalAppendValue(sourceBindings, items), \
          MalMkList2(MalMkSymbol("clojure.core/seq"), source))
        sourceBindings init MalAppendValue(MalAppendValue(sourceBindings, size), \
          MalMkList2(MalMkSymbol("clojure.core/count"), items))
        itemBinding:MalValue init MalMkValue($MAL_VECTOR_TYPE)
        itemBinding init MalAppendValue(MalAppendValue(itemBinding, pattern), \
          MalMkList3(MalMkSymbol("clojure.core/nth"), items, index))
        step:MalValue init MalIterationStep(index, size, MalMkList3(MalMkSymbol("let"), itemBinding, nested))
        iterate:MalValue init MalMkList3(MalMkSymbol("let"), sourceBindings, step)
        result init MalMkList3(MalMkSymbol("do"), iterate, again)
      endif
    endif
  endif
  xout result
endop

opcode MalExpandIteration(kind:MalValue, args:MalValue):MalValue
  if (MalIsSymbolNamed(kind, "loop") == 1) ithen
    result:MalValue init MalExpandLoop(args)
  elseif (MalIsSymbolNamed(kind, "dotimes") == 1) ithen
    result init MalExpandDotimes(args)
  else
    result init MalMkError("doseq: expected an even binding vector")
    if (args.length > 0) ithen
      bindings:MalValue init MalAt(args, 0)
      if (bindings.type == $MAL_VECTOR_TYPE && bindings.length % 2 == 0) ithen
        result init MalExpandDoseqBody(bindings, 0, MalBodyForms(args, 1), MalMkValue($MAL_NIL_TYPE))
      endif
    endif
  endif
  xout result
endop

opcode MalInstallIterationForms(env:MalEnv):MalEnv
  current:MalEnv init MalEnvSet(env, "core/iteration", MalMkBuiltin("core/iteration"))
  source:S init {{
(do
  (defmacro loop [& forms] (core/iteration 'loop forms))
  (defmacro dotimes [& forms] (core/iteration 'dotimes forms))
  (defmacro doseq [& forms] (core/iteration 'doseq forms)))
}}
  result:MalValue, current = MalEvalSourceEnv(source, current)
  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "iteration macro bootstrap failed: %s\n", result.string
  endif
  xout current
endop
