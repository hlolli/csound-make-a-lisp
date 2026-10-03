# Csound MAL

A MAL interpreter written in Csound 7, with Clojure-style helpers and Csound
instrument support.

Use `def`, `defn`, and `defmacro` for definitions, and atoms for changing state:

```clojure
(def counter (atom 0))
(defn tick! [] (swap! counter inc))
(tick!)
;; 1
@counter
;; 1
```

Collection updates return new values. Global definitions can be replaced,
as in Clojure; `let` bindings keep their values. See
[definitions and state](CORE.md#definitions-and-state) for syntax and limits.
The original MAL forms still work for existing programs and self-hosting.

Use `ns` to group definitions and `require` to load `.mal` libraries:

```clojure
(ns music.main (:require [music.notes :as notes]))
(notes/add-note! 67)
```

Each namespace owns its definitions and aliases. Libraries can share atoms
through qualified names. See
[namespaces](CORE.md#namespaces) for the file layout and supported forms.

## Build the include file

```sh
just build
```

This writes `dist/mal-<version>.inc`, using the version in `VERSION`. Git ignores
`dist/`. The build uses Python 3.9 or later and its standard library. You can
also run it directly and choose an output path:

```sh
python3 tools/bundle.py --output dist/mal.inc
```

The file contains the full interpreter, core helpers, threading macros, and
Csound interop. It expands the includes in `src/main.orc` and keeps the code,
comments, and embedded Lisp strings readable. The host orchestra supplies its
audio settings and entry instrument.

The header includes the author, full MPL 2.0 license, version from `VERSION`,
Git commit and commit date, working tree state, and a SHA-256 checksum of the
bundled source. Local edits mark the build as `modified`. A source archive
without Git metadata uses `unknown` for the revision fields. The build adds no
current timestamp, so the same inputs and Git state produce identical bytes.

## Use the bundle

Download the include from [Releases](https://github.com/hlolli/csound-make-a-lisp/releases),
or build it locally. Copy `mal-<version>.inc` beside your orchestra, rename it
to `mal.inc`, and include it:

```csound
#include "mal.inc"

instr 1
  env:MalEnv = MalMkCsoundEnv()
  value:MalValue, nextEnv:MalEnv = MalEvalSourceEnv( \
    "(->> [1 2 3] (map inc) (reduce +))", env)
  prints "%s\n", pr_str(value)
endin

schedule(1, 0, 0)
event_i("e", 0, 0)
```

This prints `9`. Keep `nextEnv` when evaluating more forms in the same session.
The include guard permits repeated inclusion. Only `mal.inc` and Csound 7 are
needed at runtime; the source checkout and reference MAL implementation are
not required. The generated file contains its license and can be distributed
on its own. Rebuild it after editing `src/` or changing `VERSION`.

## Live evaluation

For live coding in the Csound Web-IDE, see the
[Web-IDE example](examples/web-ide/README.md). It includes a persistent
`LispEval` hook, a Lisp file, and the WebMCP evaluation steps.

Use `MalEvalFormsEnv(source, env)` for a region or file containing several
forms. It returns the last value and the updated environment. Keep that
environment for the next call. `MalEvalSourceEnv` still reads one form.

## Check the bundle

```sh
just --set csound /path/to/csound bundle-check
```

This builds twice to check reproducibility, then loads the include in a
temporary directory with no library source files. It checks Step A, repeated
inclusion, core helpers and macros, file loading, and Csound audio interop.
`just test` also runs this check. See [tests/README.md](tests/README.md) for the
other suites, [CORE.md](CORE.md) for helpers, and [INTEROP.md](INTEROP.md) for
instrument support.

## Releases

`VERSION` is the only place to set the release version. Use a semantic version
such as `1.2.3` or `1.2.3-rc.1`. Commit a change to that file and push it to
`main`. The [release workflow](.github/workflows/release.yml) checks the build,
creates a `v<version>` tag at that commit, and publishes `mal-<version>.inc`
as a GitHub release asset. Versions with a prerelease suffix produce prereleases.

The workflow uses Llama 3.2 through the Ollama setup action to turn commit
subjects since the previous tag into short release notes. It runs on the
GitHub runner and needs no model API key. If setup or generation fails, or the
model returns an empty or malformed reply, the release uses a linked commit
list. Both forms include a link to the full history.

Pull requests that change the release tools run packaging checks without
publishing. You can also run the workflow by hand on `main`. A rerun leaves an
existing release alone; a tag at another commit requires a new version. If a
failed publish leaves a draft, finish or delete that draft before retrying.

To check packaging and preview the commit-list notes without publishing:

```sh
just release-check
python3 tools/release.py prepare
```

The preview writes the include, `dist/release-notes.md`, and `dist/release.json`.
With Ollama installed, `python3 tools/release.py summarize` also tries the
Llama summary. It downloads `llama3.2:3b` on first use.

Copyright (C) 2026 Hlöðver Sigurðsson. Licensed under
[MPL 2.0](LICENSE). See [NOTICE.md](NOTICE.md) for attribution.
