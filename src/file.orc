;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; The reader runs synchronously at init time and never calls MAL code.
malFilePath@global:S init ""
malFileContent@global:S init ""

instr MalFileReader
  malFileContent = ""

read_line:
  line:S, lineNumber:i readfi malFilePath
  if (lineNumber != -1) ithen
    malFileContent strcat malFileContent, line
    igoto read_line
  endif
endin

malFileReader@global:Instr = create(MalFileReader)
;; delete runs at deinit, after the file-reading calls have finished.
delete(malFileReader)

opcode MalSlurpFile(filename:S):MalValue
  ;; Turning off the reader resets readfi's EOF state. Reuse one instance
  ;; so repeated slurp calls do not retain an instrument for every file.
  malFilePath strcpy filename
  status:i = init(malFileReader)
  result:MalValue init MalMkString(malFileContent)
  turnoff(malFileReader)

  if (status != 0) ithen
    result init MalMkError(sprintf("slurp: could not read %s", filename))
  endif
  xout result
endop
