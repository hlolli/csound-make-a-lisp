#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

malReplEnv@global:MalEnv init MalMkCsoundEnv()

instr MAL_REPL
  Sescape sprintf "%c", 27
  Sprompt sprintf "%s[1;36mmal%s[0m %s[2m>%s[0m ", \
    Sescape, Sescape, Sescape, Sescape
  SreplPrompt strcpy Sprompt
  SpendingSource init ""
  iAwaitingInput init 0
  Sline init ""
  kstatus init 0

  prints "%s[1mMAL in Csound7%s[0m\n", Sescape, Sescape
  prints "Type :help for examples or :quit to exit.\n\n"
  igoto READY
  kgoto READY

EVALUATE:
  iQuit:i = strcmp(Sline, ":quit") == 0 || strcmp(Sline, ":q") == 0

  if (iAwaitingInput == 0 && iQuit == 1) ithen
    event_i "i", "MAL_EXIT", 0, 0
    rireturn
  endif

  if (iAwaitingInput == 1) ithen
    iQueued:i = MalInputEnqueue(Sline, $MAL_INPUT_LINE)
    Sinput strcpy SpendingSource
    Sprompt strcpy SreplPrompt
    iAwaitingInput = 0
  else
    candidate:MalValue init read_str(Sline)
    SrequestedPrompt:S, iIsRequest:i = MalInputPromptFromForm(candidate)
    readlineFn:MalValue init MalEnvGet(malReplEnv, "readline")
    iUsesBuiltin:i = readlineFn.type == $MAL_BUILTIN_TYPE && \
      strcmp(readlineFn.string, "readline") == 0

    if (iIsRequest == 1 && iUsesBuiltin == 1) ithen
      SpendingSource strcpy Sline
      Sprompt strcpy SrequestedPrompt
      iAwaitingInput = 1
      rireturn
    endif

    iQueued init MalInputEnqueue(Sline, $MAL_INPUT_LINE)

    if (iQueued == 1) ithen
      input:MalValue init MalInputTake()
      Sinput strcpy input.string
    endif
  endif

  if (iQueued == 0) ithen
    prints "%s[31minput inbox is full%s[0m\n", Sescape, Sescape
    rireturn
  endif

  if (strcmp(Sinput, ":help") == 0) ithen
    Shelp init "Try these forms:\n  (+ 1 2)\n"
    Shelp strcat Shelp, "  (def! square (fn* (x) (* x x)))\n"
    Shelp strcat Shelp, "  (map square [1 2 3 4])\n"
    Shelp strcat Shelp, "  (def! counter (atom 0))\n"
    Shelp strcat Shelp, "  (swap! counter + 1)\n"
    Shelp strcat Shelp, \
      "  (try* (throw \"boom\") (catch* error error))\n"
    prints "%s", Shelp
  else
    inputTokens:MalTokens init tokenize(Sinput)

    if (inputTokens.length > 0) ithen
      ast:MalValue init read_str(Sinput)

      if (ast.type == $MAL_ERROR_TYPE) ithen
        prints "%s[31m%s%s[0m\n", Sescape, ast.string, Sescape
      else
        evaluated:MalValue, nextEnv:MalEnv = EVAL_ENV(ast, malReplEnv)
        malReplEnv = nextEnv

        if (evaluated.type == $MAL_ERROR_TYPE) ithen
          prints "%s[31m%s%s[0m\n", Sescape, evaluated.string, Sescape
        else
          Sresult:S init pr_str(evaluated)
          prints "%s\n", Sresult
        endif
      endif
    endif
  endif
  rireturn

READY:
  Sline, kstatus readline Sprompt

  if (kstatus == 1) then
    reinit EVALUATE
  elseif (kstatus < 0) then
    event "i", "MAL_EXIT", 0, 0
  endif
endin

instr MAL_EXIT
  prints "\n"
  exitnow(0)
endin

schedule("MAL_REPL", 0, -1)
