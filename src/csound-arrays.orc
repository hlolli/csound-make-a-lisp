;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalCsoundArray(rate:MalValue, values:MalValue):MalValue
  result:MalValue init MalMkError("csound/array: expected :i, :k, :a or :S and a vector")
  if (rate.type == $MAL_KEYWORD_TYPE && strlen(rate.string) == 1 && \
      strindex("ikaS", rate.string) >= 0 && values.type == $MAL_VECTOR_TYPE) ithen
    arrayType:S init sprintf("%s[]", rate.string)
    result init MalMkCsoundNode("array", $MAL_CSOUND_ARRAY_NODE, arrayType, values)
    if (values.length > 0) ithen
      for index in [0 ... values.length - 1] do
        actual:S init MalCsoundTypes(MalAt(values, index))
        if (MalCsoundTypeCost(actual, rate.string) < 0) ithen
          result init MalMkError(sprintf("csound/array: element %d expected %s, got %s", \
            index, rate.string, actual))
          break
        endif
      od
    endif
  endif
  xout result
endop

opcode MalIsCsoundArray(value:MalValue):i
  result:i = 0
  if (value.type == $MAL_CSOUND_NODE_TYPE) ithen
    types:S init MalCsoundTypes(value)
    result = strlen(types) == 3 && strcmp(strsub(types, 1), "[]") == 0
  endif
  xout result
endop

;; A write keeps its input's shape. Opcode-produced arrays have unknown size.
opcode MalCsoundArraySize(array:MalValue):i
  current:MalValue init array
  while (current.number == $MAL_CSOUND_ARRAY_SET_NODE) do
    current init MalAt(current, 2)
  od
  size:i = current.number == $MAL_CSOUND_ARRAY_NODE ? current.length - 2 : -1
  xout size
endop

opcode MalCsoundArrayIndex(array:MalValue, index:MalValue, name:S):MalValue
  indexType:S init MalCsoundTypes(index)
  result:MalValue init MalMkError(sprintf("%s: expected a one-dimensional array and an init- or control-rate index", name))
  if (MalIsCsoundArray(array) == 1 && \
      (strcmp(indexType, "i") == 0 || strcmp(indexType, "k") == 0)) ithen
    size:i = MalCsoundArraySize(array)
    if (index.type == $MAL_NUMBER_TYPE && (index.number < 0 || \
        int(index.number) != index.number)) ithen
      result init MalMkError(sprintf("%s: index must be a nonnegative integer", name))
    elseif (size >= 0 && index.type == $MAL_NUMBER_TYPE && index.number >= size) ithen
      result init MalMkError(sprintf("%s: index out of bounds", name))
    else
      result init MalMkValue($MAL_NIL_TYPE)
    endif
  endif
  xout result
endop

opcode MalCsoundArrayRead(array:MalValue, index:MalValue, name:S):MalValue
  result:MalValue init MalCsoundArrayIndex(array, index, name)
  if (result.type != $MAL_ERROR_TYPE) ithen
    rate:S init strsub(MalCsoundTypes(array), 0, 1)
    if (strcmp(rate, "i") == 0 && strcmp(MalCsoundTypes(index), "k") == 0) ithen
      rate init "k"
    endif
    result init MalMkCsoundNode("aget", $MAL_CSOUND_INDEX_NODE, rate, MalMkList2(array, index))
  endif
  xout result
endop

opcode MalCsoundArrayAt(array:MalValue, index:MalValue):MalValue
  xout MalCsoundArrayRead(array, index, "csound/aget")
endop

opcode MalCsoundArrayCount(array:MalValue):MalValue
  xout MalMkCsoundNode("lenarray", $MAL_CSOUND_CALL_NODE, "i", MalMkList1(array))
endop

opcode MalCsoundArrayWrite(array:MalValue, index:MalValue, value:MalValue):MalValue
  result:MalValue init MalCsoundArrayIndex(array, index, "assoc")
  if (result.type != $MAL_ERROR_TYPE) ithen
    types:S init MalCsoundTypes(array)
    rate:S init strsub(types, 0, 1)
    if (strcmp(rate, "i") == 0 && strcmp(MalCsoundTypes(index), "i") != 0) ithen
      result init MalMkError("assoc: init-rate arrays require an init-rate index")
    elseif (MalCsoundTypeCost(MalCsoundTypes(value), rate) < 0) ithen
      result init MalMkError(sprintf("assoc: array element expected %s, got %s", rate, MalCsoundTypes(value)))
    else
      args:MalValue init MalMkList2(array, index)
      args init MalAppendValue(args, value)
      result init MalMkCsoundNode("aset", $MAL_CSOUND_ARRAY_SET_NODE, types, args)
    endif
  endif
  xout result
endop

;; Sequence functions run while building the graph, so they need a known size.
;; The resulting elements are native array reads, not copies of sample data.
opcode MalCsoundArraySeq(array:MalValue):MalValue
  size:i = MalCsoundArraySize(array)
  result:MalValue init MalMkValue($MAL_LIST_TYPE)
  if (size < 0) ithen
    result init MalMkError("seq: Csound array length is only known at instrument runtime")
  elseif (size > 0) ithen
    for index in [0 ... size - 1] do
      result init MalAppendValue(result, MalCsoundArrayAt(array, MalMkNumber(index)))
    od
  endif
  xout result
endop
