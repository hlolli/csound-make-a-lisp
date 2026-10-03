;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode ASSERT_NAMESPACE(source:S, expected:S, env:MalEnv):MalEnv
  value:MalValue, updated:MalEnv = MalEvalSourceEnv(source, env)
  actual:S init pr_str(value)
  if (strcmp(actual, expected) != 0) ithen
    prints "FAIL: %s: expected %s, got %s\n", source, expected, actual
    exitnow(1)
  endif
  xout updated
endop

instr TEST
  first:MalEnv init MalMkStepAEnv()
  second:MalEnv init MalMkStepAEnv()
  first init ASSERT_NAMESPACE( \
    "(do (ns shared) (def state (atom 1)) (ns user) (alias 's 'shared))", "nil", first)
  second init ASSERT_NAMESPACE( \
    "(and (= *ns* 'user) (nil? (find-ns 'shared)) (= {} (ns-aliases 'user)))", "true", second)
  second init ASSERT_NAMESPACE( \
    "(do (ns shared) (def state (atom 2)) (swap! state inc) (= (deref state) 3))", "true", second)
  first init ASSERT_NAMESPACE( \
    "(and (= (deref s/state) 1) (= *ns* 'user))", "true", first)
  ;; Hosts can add bindings after namespace setup and replace them in place.
  first init MalEnvSet(first, "host-value", MalMkNumber(7))
  first init ASSERT_NAMESPACE("clojure.core/host-value", "7", first)
  first init MalEnvSet(first, "host-value", MalMkNumber(8))
  first init ASSERT_NAMESPACE("host-value", "8", first)
  prints "PASS: namespace session isolation and host bindings\n"
  exitnow(0)
endin

schedule("TEST", 0, 0)
