# Core helpers

These helpers follow [Clojure core](https://clojure.github.io/clojure/clojure.core-api.html).
Sequence transforms evaluate eagerly. Use finite inputs.

## Definitions and state

The [Clojure MAL implementation](https://github.com/kanaka/mal/tree/master/impls/clojure)
is the closest reference for these changes. Its
[core](https://github.com/kanaka/mal/blob/master/impls/clojure/src/mal/core.cljc)
uses Clojure's immutable collections and atoms directly, while its guest
language still uses MAL's `def!` and `defmacro!` forms.

Csound MAL adds these forms:

| Form | Use |
| --- | --- |
| `(def name value)` | Define or replace a global name. Return the value. |
| `(defn name [args] body...)` | Define a global function. |
| `(defmacro name [args] body...)` | Define a global macro that receives unevaluated forms. |
| `(fn [args] body...)` | Create a function that captures its local scope. |
| `(let [name value ...] body...)` | Bind local names in order. |

Functions and macros accept `& rest-args`. Each body runs in order and returns
its last value, or `nil` for an empty body. Names must be symbols. Parameter
and binding lists use vectors. This is a small Clojure subset: it does not
support destructuring, multiple arities, named `fn`, docstrings, or attribute
maps. `def` requires a value; the interpreter has no Var objects.

`def`, `defn`, and `defmacro` write to the current namespace, even inside
a function or `let`. A function keeps the namespace where it was defined.
Value expressions can use local bindings. A
definition does not replace a local binding of the same name. Closures keep
earlier local values when a later `let` binding shadows a name:

```clojure
(let [x 1
      read-x (fn [] x)
      x 2]
  [(read-x) x])
;; [1 2]
```

As in [Clojure](https://clojure.org/reference/vars), a global name can be
redefined. Removing `!` does not make definitions write-once. Use
[atoms](https://clojure.org/reference/atoms) for changing program state:

```clojure
(def initial {:notes [60 64] :gain 0.2})
(def voice (atom initial))
(def before @voice)

(defn add-note! [note]
  (swap! voice update :notes conj note))

(add-note! 67)
;; {:notes [60 64 67] :gain 0.2}
before
;; {:notes [60 64] :gain 0.2}
(reset! voice initial)
;; {:notes [60 64] :gain 0.2}

(defmacro unless [test & body]
  (list 'if test nil (cons 'do body)))
```

`assoc`, `dissoc`, `conj`, `update`, and nested updates leave their inputs
unchanged for MAL collections. Csound arrays use native reads and writes;
see [collection operators on Csound arrays](INTEROP.md#collection-operators-on-csound-arrays).
For MAL values, `assoc` accepts maps, vectors, and `nil`; a vector index equal to
its length appends an item. Saved values from `@voice` stay unchanged after
`swap!` or `reset!`. A failed swap leaves the atom's value in place. Atoms have
shared identity: two names for the same atom see the same updates, including
when the atom sits inside a collection. These atoms run in the interpreter's
single init-time evaluation; they do not add Clojure's thread coordination,
validators, or watches.

Map keys use the same equality rules as `=`. Lists and vectors with equal
items select the same entry, including nested collections. Map keys ignore
entry order; metadata does not affect lookup. For example:

```clojure
(get (assoc {} ["voice" [1 2]] 42) '("voice" (1 2)))
;; 42
```

The original `def!`, `defmacro!`, `fn*`, and `let*` retain their MAL behavior
for compatibility. In particular, `def!` writes to the current scope. New
programs should use the forms above and atoms for state changes.

## Namespaces

Step A and Csound environments start in `user`. Each interpreter session has
its own namespaces. `(ns music.notes)` creates or selects a namespace and
makes `clojure.core` helpers available. Definitions belong to that namespace;
local bindings take precedence. Use a full name such as `music.notes/state`
to read a definition from another namespace.

```clojure
;; music/notes.mal
(ns music.notes)
(def state (atom [60 64]))
(defn add-note! [note] (swap! state conj note))

;; main.mal
(ns music.main (:require [music.notes :as notes :refer [add-note!]]))
(add-note! 67)
@notes/state
;; [60 64 67]
```

`require` loads each library once. It maps dots to directories and hyphens to
underscores: `music.low-notes` loads `music/low_notes.mal`. It searches the
working directory, then directories of files loaded in this session, in the
order they were first used. Put `main.mal` beside the `music` directory in this
example. Each library must declare its own namespace with `ns`.
`load-file` evaluates a file on every call. Both loaders restore the caller's
namespace after success or failure. Failed imports can be retried; circular
imports report an error.

At the REPL, quote the library specifications:

```clojure
(require '[music.notes :as notes :refer [add-note!]])
(require 'music.notes)
```

Functions and closures resolve names in their defining namespace. Aliases
and referred names stay local to the importing namespace and follow later
redefinitions. Macros run in their defining namespace; their generated forms
run in the caller's scope. MAL quasiquote does not qualify symbols for you.
Use full names for helpers in generated forms that must resolve in a specific
namespace.

| Operation | Behavior |
| --- | --- |
| `*ns*` | Current namespace, represented as a symbol. |
| `(in-ns 'name)` | Select or create a namespace without adding core helpers. |
| `(create-ns 'name)` | Create a namespace without selecting it. |
| `(find-ns 'name)`, `(all-ns)`, `(ns-name *ns*)` | Find and inspect namespace names. |
| `(ns-publics 'name)` | Map of definitions owned by the namespace, with their current values. |
| `(ns-aliases 'name)` | Map of aliases to namespace symbols. |
| `(alias 'short 'full.name)` | Add an alias to an existing namespace. |
| `(refer 'full.name :only '[f g])` | Refer to selected definitions; omit `:only` to refer to all. |
| `(name :music/note)`, `(namespace :music/note)` | Return `"note"` and `"music"`; also accept symbols. |

`:require` accepts symbols or `[library :as alias :refer [names]]`;
`:refer :all` is also supported. `ns` supports only `:require` clauses. This subset
does not include Vars, private definitions, JVM imports, reload flags,
classpath configuration, automatic keyword resolution, or Clojure syntax-quote.
The earlier MAL learning steps keep their original global environment.

## Collection and function helpers

| Use | Functions |
| --- | --- |
| Numbers and truth values | `inc`, `dec`, `mod`, `zero?`, `pos?`, `neg?`, `some?`, `boolean`, `not=` |
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

Fraction literals such as `1/3`, `-1/4`, and `7/2` read as numbers. The numerator
is a signed integer; the denominator is an unsigned integer and must not be
zero. They use Csound's double precision, not exact rational arithmetic, and
print as decimals. For example, `[1/4 1/2 3/4]` reads as `[0.25 0.5 0.75]`.
This does not change `/`, which still performs truncating division.

`mod` takes two numbers and returns a remainder with the divisor's sign, as in
[Clojure](https://clojure.github.io/clojure/clojure.core-api.html#clojure.core/mod).
For example, `(mod 4 3)` returns `1` and `(mod -1 3)` returns `2`. A zero divisor
raises an error. Use `(nth items (mod step (count items)))` to wrap an index
through a nonempty vector; `nth` itself still checks its bounds.

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
