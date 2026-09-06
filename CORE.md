# Core helpers

These helpers follow [Clojure core](https://clojure.github.io/clojure/clojure.core-api.html).
Sequence transforms evaluate eagerly. Use finite inputs.

| Use | Functions |
| --- | --- |
| Numbers and truth values | `inc`, `dec`, `zero?`, `pos?`, `neg?`, `some?`, `boolean`, `not=` |
| Compose functions | `identity`, `constantly`, `complement`, `partial`, `comp`, `juxt` |
| Read sequences | `next`, `second`, `last`, `butlast`, `reverse`, `not-empty` |
| Transform collections | `reduce`, `filter`, `remove`, `keep`, `mapv`, `filterv` |
| Test collections | `every?`, `not-every?`, `some`, `not-any?` |
| Select sequence items | `take`, `drop`, `take-while`, `drop-while` |
| Work with nested data | `get-in`, `assoc-in`, `update`, `update-in`, `select-keys`, `merge` |
| End a reduction | `reduced`, `reduced?`, `ensure-reduced`, `unreduced` |

```clojure
(->> [-2 0 3 5]
     (filter pos?)
     (mapv inc)
     (reduce + 0))
;; 10

((comp inc (partial * 2)) 4)
;; 9

((juxt inc dec) 3)
;; [4 2]

(update-in {:voice {:amplitude 0.2}} [:voice :amplitude] * 0.5)
;; {:voice {:amplitude 0.1}}

(get-in {:voice {:pan nil}} [:voice :pan] 0.5)
;; nil
```

`mapv` accepts several collections and stops at the shortest one. `keep` drops
only `nil`; `some` returns the first truthy predicate result. `get-in` accepts
a default for missing keys. Nested updates support maps and vectors and create
missing map levels. `seq` turns a map into a list of key/value vectors.

`reduce` accepts a function and collection, with an optional initial value
between them. Return `(reduced value)` from the function to stop. Use `deref`
or `unreduced` to unwrap that value outside a reduction.

## Conditionals

`and` and `or` stop once the result is known and return the deciding value.
`when` and `when-not` accept several body forms. `if-let` and `when-let` bind
a truthy value; `if-some` and `when-some` bind any value except `nil`.

```clojure
(if-some [pan (get-in {:voice {:pan 0}} [:voice :pan])]
  pan
  0.5)
;; 0

(when-let [voice (get {:voice {:amplitude 0.2}} :voice)]
  (println voice)
  (get voice :amplitude))
```

Bindings use `[name expression]`. The expression runs once, and the name stays
within the selected body. The seven [threading macros](INTEROP.md#threading-macros)
work with these helpers and with Csound graphs.
