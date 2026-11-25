;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode CheckLanguage(source:S, expected:S, env:MalEnv):void
  ast:MalValue init read_str(source)
  actual:MalValue init EVAL(ast, env)
  if (strcmp(pr_str(actual), expected) != 0) ithen
    prints "FAIL synchronous %s\nexpected %s, got %s\n", source, expected, pr_str(actual)
    exitnow(1)
  endif

  id:i = MalEvalJobStart(ast, env)
  status:i = 0
  steps:i = 0
  while (status == 0 && steps < 3000) do
    status = MalEvalJobStep(id, 7)
    steps += 1
  od
  actual init MalEvalJobResult(id)
  MalEvalJobCancel(id)
  if (status != 1 || strcmp(pr_str(actual), expected) != 0) ithen
    prints "FAIL resumable %s\nexpected %s, got %s\n", source, expected, pr_str(actual)
    exitnow(1)
  endif
endop

instr TEST
  env:MalEnv init MalMkStepAEnv()
  CheckLanguage("#_ 0 [1 #_(bad) 2 #_foo]", "[1 2]", env)
  CheckLanguage("'#_ 1 2", "2", env)
  CheckLanguage("[1 #_ #_ 2 3 4]", "[1 4]", env)
  CheckLanguage("#_ (bad)", "nil", env)
  CheckLanguage("(#(vector % %1 %3 %&) 2 4 7 9 11)", "[2 2 7 (9 11)]", env)
  CheckLanguage("(#(list))", "()", env)
  CheckLanguage("(try* (read-string \"#(#(list %))\") (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* (read-string \"#_%\") (catch* e :caught))", "nil", env)
  CheckLanguage("(try* (read-string \"#_\") (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* (read-string \"#(list %9999999999)\") (catch* e :caught))", ":caught", env)
  value:MalValue, env = MalEvalFormsEnv("#_ (bad) (def region 41) #_ (bad) (inc region) #_ (bad)", env)
  if (strcmp(pr_str(value), "42") != 0) ithen
    prints "FAIL discarded region form: %s\n", pr_str(value)
    exitnow(1)
  endif

  CheckLanguage("(let [[x [y] & more :as all] [1 [2] 3 4]] [x y more all])", "[1 2 (3 4) [1 [2] 3 4]]", env)
  CheckLanguage("(let [[x & more :as all] nil] [x more all])", "[nil nil nil]", env)
  CheckLanguage("(let [{:keys [x y] :strs [s] :syms [t] :or {y 4} :as all} (hash-map :x nil \"s\" 7 't 8)] [x y s t (get all :x)])", \
    "[nil 4 7 8 nil]", env)
  CheckLanguage("(let [{:music/keys [pitch] [a b] :note} {:music/pitch 60 :note [2 4]}] [pitch a b])", "[60 2 4]", env)
  CheckLanguage("(let [{:track/keys [sound/gain]} {:sound/gain 4 :track/gain 5}] gain)", "5", env)
  CheckLanguage("(let [{foo/left :l :right :r} {:l 2 :r 3}] [left right])", "[2 3]", env)
  CheckLanguage("(let [{:keys [x]} nil] x)", "nil", env)
  CheckLanguage("((fn [[a b] {:keys [scale]}] (* (+ a b) scale)) [1 2] {:scale 3})", "9", env)
  CheckLanguage("((fn [& {:keys [pitch velocity] :or {velocity 100}}] [pitch velocity]) :pitch 60)", "[60 100]", env)
  CheckLanguage("((fn [& {:keys [pitch velocity]}] [pitch velocity]) :pitch 60 {:pitch 61 :velocity 90})", "[61 90]", env)
  CheckLanguage("(let [seen (atom 0) [a b] (do (swap! seen inc) [2 3])] [a b (deref seen)])", "[2 3 1]", env)
  CheckLanguage("(if-let [[a b] [2 3]] (+ a b) 0)", "5", env)

  CheckLanguage("(let [f (fn self ([n] (self n 1)) ([n acc] (if (= n 0) acc (recur (dec n) (* n acc)))))] (f 5))", "120", env)
  CheckLanguage("(do (defn choose ([x] x) ([x y & more] [x y more])) [(choose 1) (choose 1 2 3)])", "[1 [1 2 (3)]]", env)
  CheckLanguage("(do (defmacro form ([] 7) ([x] (list 'quote x))) [(form) (form this)])", "[7 this]", env)
  CheckLanguage("((fn ([x] :fixed) ([x & more] :variadic)) 1)", ":fixed", env)
  CheckLanguage("((fn [n & rest] (if (= n 0) rest (recur 0 [1 2]))) 1 5)", "[1 2]", env)
  CheckLanguage("(try* (fn ([x] 1) ([y] 2)) (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* (fn ([a b] 1) ([x & rest] 2)) (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* ((fn ([x] x) ([x y] y))) (catch* e :caught))", ":caught", env)

  CheckLanguage("(loop [x 1 x (inc x)] x)", "2", env)
  CheckLanguage("(loop [[x] [0] max (+ x 3)] (if (< x max) (recur [(inc x)] max) x))", "3", env)
  CheckLanguage("(loop [i 0] (when (< i 5) (recur (inc i))))", "nil", env)
  CheckLanguage("(loop [i 0] (if-let [x (if (< i 6) (inc i) nil)] (recur x) i))", "6", env)
  CheckLanguage("(loop [i 0 f nil] (if (= i 0) (recur 1 (fn [] i)) (f)))", "0", env)
  CheckLanguage("(try* (recur 0) (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* (loop [i 0] (+ 1 (recur 1))) (catch* e :caught))", ":caught", env)
  CheckLanguage("(try* (loop [i 0] (recur)) (catch* e :caught))", ":caught", env)
  CheckLanguage("(let [calls (atom 0)] [(try* (loop [i 0] (recur (swap! calls inc) 1)) (catch* e :caught)) (deref calls)])", "[:caught 0]", env)
  CheckLanguage("(try* (loop [i 0] (try* (throw :try) (catch* e (recur 1)))) (catch* e :caught))", ":caught", env)

  CheckLanguage("(let [seen (atom []) n (atom 0)] [(dotimes [i (do (swap! n inc) 3.5)] (swap! seen conj i)) (deref seen) (deref n)])", \
    "[nil [0 1 2] 1]", env)
  CheckLanguage("(let [seen (atom [])] [(dotimes [i -1] (swap! seen conj i)) (deref seen)])", "[nil []]", env)
  CheckLanguage("(let [seen (atom [])] [(doseq [[x] [[1] [2]] y [0 1 2] :while (< y 2) :let [p (+ x y)] :when (> p 1) :when (< p 4)] (swap! seen conj [x y p])) (deref seen)])", \
    "[nil [[1 1 2] [2 0 2] [2 1 3]]]", env)
  CheckLanguage("(let [seen (atom 0)] [(doseq [] (swap! seen inc)) (doseq [x nil] (swap! seen inc)) (deref seen)])", "[nil nil 1]", env)
  CheckLanguage("(try* (doseq [x [1] :unknown true] x) (catch* e :caught))", ":caught", env)
  prints "PASS: Clojure reader, binding, arity, and iteration forms in both evaluators\n"
  exitnow(0)
endin
schedule("TEST", 0, 0)
