malInputLines@global:S[] init $MAL_INPUT_CAPACITY
malInputStatuses@global:i[] init $MAL_INPUT_CAPACITY
malInputReadIndex@global:i init 0
malInputWriteIndex@global:i init 0
malInputCount@global:i init 0

opcode MalInputClear():void
  malInputReadIndex = 0
  malInputWriteIndex = 0
  malInputCount = 0
endop

opcode MalInputEnqueue(line:S, status:i):i
  accepted:i = 0
  validStatus:i = status == $MAL_INPUT_LINE || status == $MAL_INPUT_EOF

  if (validStatus == 1 && malInputCount < $MAL_INPUT_CAPACITY) then
    malInputLines[malInputWriteIndex] = line
    malInputStatuses[malInputWriteIndex] = status
    malInputWriteIndex = (malInputWriteIndex + 1) % $MAL_INPUT_CAPACITY
    malInputCount += 1
    accepted = 1
  endif

  xout accepted
endop

opcode MalInputTake():MalValue
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  if (malInputCount > 0) then
    status:i = malInputStatuses[malInputReadIndex]
    line:S = malInputLines[malInputReadIndex]
    malInputReadIndex = (malInputReadIndex + 1) % $MAL_INPUT_CAPACITY
    malInputCount -= 1

    if (status == $MAL_INPUT_LINE) then
      result = MalMkString(line)
    endif
  endif

  xout result
endop

opcode MalInputPending():i
  xout malInputCount
endop

opcode MalInputPromptFromForm(ast:MalValue):(S, i)
  prompt:S = ""
  isRequest:i = 0

  if (ast.type == $MAL_LIST_TYPE && ast.length == 2) then
    head:MalValue = MalAt(ast, 0)
    argument:MalValue = MalAt(ast, 1)

    if (head.type == $MAL_SYMBOL_TYPE && \
        strcmp(head.string, "readline") == 0 && \
        argument.type == $MAL_STRING_TYPE) then
      prompt = argument.string
      isRequest = 1
    endif
  endif

  xout prompt, isRequest
endop
