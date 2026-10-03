;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalInstallThreadingMacros(env:MalEnv):MalEnv
  source:S init {{
(do
  (defn threading/step [last? value form]
    (if (list? form)
      (with-meta
        (if last?
          (concat form (list value))
          (cons (first form) (cons value (rest form))))
        (meta form))
      (list form value)))

  (defn threading/expand [last? value forms]
    (if (empty? forms)
      value
      (threading/expand last?
                        (threading/step last? value (first forms))
                        (rest forms))))

  (defn threading/some [last? value forms]
    (if (empty? forms)
      value
      (let* [name (gensym)]
        (list 'let* (list name value)
              (list 'if (list nil? name) nil
                    (threading/some last?
                                    (threading/step last? name (first forms))
                                    (rest forms)))))))

  (defn threading/cond [last? value clauses]
    (if (empty? clauses)
      value
      (if (= (count clauses) 1)
        (throw "conditional threading requires test/form pairs")
        (let* [name (gensym)]
          (list 'let* (list name value)
                (threading/cond last?
                                (list 'if (first clauses)
                                      (threading/step last? name (nth clauses 1))
                                      name)
                                (rest (rest clauses))))))))

  (defn threading/as [value name forms]
    (if (empty? forms)
      value
      ;; Evaluate the value before binding its name, so closures created
      ;; by a step retain the preceding binding.
      ;; Use a fresh parameter because fn* reserves & for rest arguments.
      (let* [parameter (gensym)]
        (list (list 'fn* (list parameter)
                    (list 'let* (list name parameter)
                          (threading/as (first forms) name (rest forms))))
              value))))

  (defmacro -> [value & forms] (threading/expand false value forms))
  (defmacro ->> [value & forms] (threading/expand true value forms))
  (defmacro some-> [value & forms] (threading/some false value forms))
  (defmacro some->> [value & forms] (threading/some true value forms))
  (defmacro cond-> [value & clauses] (threading/cond false value clauses))
  (defmacro cond->> [value & clauses] (threading/cond true value clauses))

  (defmacro as-> [value name & forms]
    (if (symbol? name)
      (threading/as value name forms)
      (throw "as->: binding name must be a symbol"))))
}}
  result:MalValue, currentEnv:MalEnv = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "threading macro bootstrap failed: %s\n", result.string
  endif

  xout currentEnv
endop
