#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

malReplEnv@global:MalEnv = MalMkStepAEnv()

instr MAL_REPL
  Sescape sprintf "%c", 27
  Sprompt sprintf "%s[1;36mmal%s[0m %s[2m>%s[0m ", \
    Sescape, Sescape, Sescape, Sescape
  Sline init ""
  kstatus init 0

  prints "%s[1mMAL in Csound7%s[0m\n", Sescape, Sescape
  prints "Type :help for examples or :quit to exit.\n\n"
  igoto READY
  kgoto READY

EVALUATE:
  Sinput strcpy Sline

  if (strcmp(Sinput, ":help") == 0) then
    Shelp = "Try these forms:\n  (+ 1 2)\n"
    Shelp strcat Shelp, "  (def! square (fn* (x) (* x x)))\n"
    Shelp strcat Shelp, "  (map square [1 2 3 4])\n"
    Shelp strcat Shelp, "  (def! counter (atom 0))\n"
    Shelp strcat Shelp, "  (swap! counter + 1)\n"
    Shelp strcat Shelp, \
      "  (try* (throw \"boom\") (catch* error error))\n"
    prints "%s", Shelp
  else
    inputTokens:MalTokens = tokenize(Sinput)

    if (inputTokens.length > 0) then
      ast:MalValue = read_str(Sinput)

      if (ast.type == $MAL_ERROR_TYPE) then
        prints "%s[31m%s%s[0m\n", Sescape, ast.string, Sescape
      else
        evaluated:MalValue, nextEnv:MalEnv = EVAL_ENV(ast, malReplEnv)
        malReplEnv = nextEnv

        if (evaluated.type == $MAL_ERROR_TYPE) then
          prints "%s[31m%s%s[0m\n", Sescape, evaluated.string, Sescape
        else
          Sresult:S = pr_str(evaluated)
          prints "%s\n", Sresult
        endif
      endif
    endif
  endif
  rireturn

READY:
  Sline, kstatus readline Sprompt
  kQuit strcmpk Sline, ":quit"
  kShortQuit strcmpk Sline, ":q"

  if (kstatus == 1) then
    if (kQuit == 0 || kShortQuit == 0) then
      event "i", "MAL_EXIT", 0, 0
    else
      reinit EVALUATE
    endif
  elseif (kstatus < 0) then
    event "i", "MAL_EXIT", 0, 0
  endif
endin

instr MAL_EXIT
  prints "\n"
  exitnow(0)
endin

schedule("MAL_REPL", 0, -1)
