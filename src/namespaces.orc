;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Namespace records belong to a root environment, so sessions stay separate.
;; Bindings live in that root under their full names. The raw bootstrap names
;; form clojure.core and remain available to the Csound host API.
;; Load status: 0 = unloaded, 1 = ready, 2 = loading, 3 = loading after ns.
malNamespaces@global:MalNamespace[] init 0
malNamespaceCount@global:i init 0

declare MalNsRequire(root:MalEnv, specs:MalValue):(MalValue)

opcode MalNameParts(name:S):(S, S)
  slash:i = strindex(name, "/")
  prefix:S init ""
  local:S init name
  if (slash > 0) ithen
    prefix init strsub(name, 0, slash)
    local init strsub(name, slash + 1)
  endif
  xout prefix, local
endop

opcode MalNsNameValid(value:MalValue):i
  valid:i = value.type == $MAL_SYMBOL_TYPE && strlen(value.string) > 0 && strindex(value.string, "/") < 0
  xout valid
endop

opcode MalNsFind(owner:i, name:S):i
  found:i = -1
  if (malNamespaceCount > 0) ithen
    for index in [0 ... malNamespaceCount - 1] do
      if (malNamespaces[index].owner == owner && strcmp(malNamespaces[index].name, name) == 0) ithen
        found = index
        break
      endif
    od
  endif
  xout found
endop

opcode MalNsEnsure(root:MalEnv, name:S, referCore:i):i
  index:i = MalNsFind(root.id, name)
  if (index < 0) ithen
    capacity:i = lenarray(malNamespaces)
    if (malNamespaceCount >= capacity) ithen
      saved:MalNamespace[] init malNamespaceCount
      if (malNamespaceCount > 0) ithen
        for item in [0 ... malNamespaceCount - 1] do
          saved[item] init malNamespaces[item]
        od
      endif
      newCapacity:i = capacity == 0 ? 16 : capacity * 2
      malNamespaces init newCapacity
      if (malNamespaceCount > 0) ithen
        for item in [0 ... malNamespaceCount - 1] do
          malNamespaces[item] init saved[item]
        od
      endif
    endif
    index = malNamespaceCount
    malNamespaceCount += 1
    empty:MalValue init MalMkValue($MAL_HASH_MAP_TYPE)
    slots:i[] init 0
    malNamespaces[index] init name, root.id, empty, empty, referCore, 0, malEmptyStrings, slots, 0
  endif
  xout index
endop

opcode MalNsSwitch(env:MalEnv, name:S):MalEnv
  root:MalEnv init MalEnvRoot(env)
  root.namespace init name
  root init MalEnvStore(root)
  xout MalEnvResolve(env)
endop

opcode MalNsRegister(root:MalEnv, key:S):void
  ;; MalEnvSet keeps these indexes current. Root slots never move; lookup
  ;; needs only names and slot numbers, without copying all global values.
  prefix:S, local:S = MalNameParts(key)
  if (strlen(prefix) == 0) ithen
    prefix init "clojure.core"
  endif
  nsIndex:i = MalNsEnsure(root, prefix, 1)
  record:MalNamespace init malNamespaces[nsIndex]
  slot:i = MalEnvFind(root, key)
  found:i = -1
  if (record.length > 0) ithen
    for index in [0 ... record.length - 1] do
      if (strcmp(record.keys[index], local) == 0) ithen
        found = index
        break
      endif
    od
  endif
  if (found >= 0) ithen
    record.slots[found] = slot
  else
    keys:S[] init record.length + 1
    slots:i[] init record.length + 1
    if (record.length > 0) ithen
      for index in [0 ... record.length - 1] do
        keys[index] init record.keys[index]
        slots[index] = record.slots[index]
      od
    endif
    keys[record.length] init local
    slots[record.length] = slot
    record.keys init keys
    record.slots init slots
    record.length += 1
  endif
  malNamespaces[nsIndex] init record
endop

opcode MalNsSlot(owner:i, namespace:S, name:S):i
  slot:i = -1
  nsIndex:i = MalNsFind(owner, namespace)
  if (nsIndex >= 0) ithen
    record:MalNamespace init malNamespaces[nsIndex]
    if (record.length > 0) ithen
      for index in [0 ... record.length - 1] do
        if (strcmp(record.keys[index], name) == 0) ithen
          slot = record.slots[index]
          break
        endif
      od
    endif
  endif
  xout slot
endop

opcode MalNsQualified(owner:i, namespace:S, name:S):MalValue
  slot:i = MalNsSlot(owner, namespace, name)
  if (slot >= 0) ithen
    result:MalValue init malEnvRegistry[owner].values[slot]
  else
    result:MalValue init MalMkError(sprintf("'%s/%s' not found", namespace, name))
  endif
  xout result
endop

opcode MalResolveSymbol(env:MalEnv, name:S):MalValue
  ;; Read registry slots directly; copying the root here copies every binding
  ;; for every symbol and DEBUG-EVAL check.
  id:i = env.id
  rootId:i = id
  if (id >= 0) ithen
    while (lenarray(malEnvRegistry[rootId].outer) > 0) do
      rootId = malEnvRegistry[rootId].outer[0].id
    od
  endif
  enabled:i = 0
  if (rootId >= 0) ithen
    enabled = strlen(malEnvRegistry[rootId].namespace) > 0
  endif
  if (enabled == 0) ithen
    result:MalValue init MalEnvGet(env, name)
  else
    namespace:S init malEnvRegistry[id].namespace
    found:i = 0
    result:MalValue init MalMkError(sprintf("'%s' not found", name))
    while (id != rootId && found == 0) do
      if (malEnvRegistry[id].length > 0) ithen
        for index in [0 ... malEnvRegistry[id].length - 1] do
          if (strcmp(malEnvRegistry[id].keys[index], name) == 0) ithen
            result init malEnvRegistry[id].values[index]
            found = 1
            break
          endif
        od
      endif
      id = malEnvRegistry[id].outer[0].id
    od
    if (found == 0) ithen
      prefix:S, local:S = MalNameParts(name)
      nsIndex:i = MalNsFind(rootId, namespace)
      if (strlen(prefix) > 0) ithen
        if (nsIndex >= 0) ithen
          aliasIndex:i = MalMapFindKey(malNamespaces[nsIndex].aliases, MalMkSymbol(prefix))
          if (aliasIndex >= 0) ithen
            target:MalValue init MalAt(malNamespaces[nsIndex].aliases, aliasIndex + 1)
            prefix init target.string
          endif
        endif
        result init MalNsQualified(rootId, prefix, local)
      elseif (strcmp(name, "*ns*") == 0) ithen
        result init MalMkSymbol(malEnvRegistry[rootId].namespace)
      else
        result init MalNsQualified(rootId, namespace, name)
        if (result.type == $MAL_ERROR_TYPE && nsIndex >= 0) ithen
          refIndex:i = MalMapFindKey(malNamespaces[nsIndex].refers, MalMkSymbol(name))
          if (refIndex >= 0) ithen
            target:MalValue init MalAt(malNamespaces[nsIndex].refers, refIndex + 1)
            targetNs:S, targetName:S = MalNameParts(target.string)
            result init MalNsQualified(rootId, targetNs, targetName)
          elseif (malNamespaces[nsIndex].core == 1) ithen
            result init MalNsQualified(rootId, "clojure.core", name)
          endif
        endif
        if (result.type == $MAL_ERROR_TYPE) ithen
          result init MalMkError(sprintf("'%s' not found", name))
        endif
      endif
    endif
  endif
  if (enabled == 1 && result.type == $MAL_BUILTIN_TYPE && strcmp(result.string, "csound/compile-inst") == 0) ithen
    ;; The compiler needs the caller's lexical namespace for the host name.
    result.number = MalNsFind(rootId, namespace) + 1
  endif
  xout result
endop

opcode MalDefinitionKey(env:MalEnv, name:S):MalValue
  current:MalEnv init MalEnvResolve(env)
  root:MalEnv init MalEnvRoot(current)
  result:MalValue init MalMkString(name)
  if (strlen(root.namespace) > 0) ithen
    prefix:S, local:S = MalNameParts(name)
    if (strlen(prefix) == 0) ithen
      prefix init current.namespace
    endif
    if (strlen(local) == 0 || (strindex(local, "/") >= 0 && strcmp(local, "/") != 0)) ithen
      result init MalMkError("def: invalid qualified name")
    elseif (MalNsFind(root.id, prefix) < 0) ithen
      result init MalMkError(sprintf("def: namespace '%s' not found", prefix))
    elseif (strcmp(local, "*ns*") == 0) ithen
      result init MalMkError("def: use ns or in-ns to change *ns*")
    else
      if (strcmp(prefix, "clojure.core") == 0) ithen
        result init MalMkString(local)
      else
        result init MalMkString(sprintf("%s/%s", prefix, local))
      endif
    endif
  endif
  xout result
endop

opcode MalNsPublics(root:MalEnv, namespace:S):MalValue
  result:MalValue init MalMkValue($MAL_HASH_MAP_TYPE)
  nsIndex:i = MalNsFind(root.id, namespace)
  if (nsIndex >= 0) ithen
    if (root.length > 0) ithen
      for index in [0 ... root.length - 1] do
        prefix:S, local:S = MalNameParts(root.keys[index])
        if (strlen(prefix) == 0) ithen
          prefix init "clojure.core"
        endif
        if (strcmp(prefix, namespace) == 0) ithen
          result init MalMapAssoc(result, MalMkSymbol(local), root.values[index])
        endif
      od
    endif
  endif
  xout result
endop

opcode MalMkNamespaceBuiltin(name:S, root:MalEnv):MalValue
  value:MalValue init MalMkBuiltin(name)
  closure:MalEnv[] init 1
  closure[0] init MalEnvHandle(root.id)
  value.env init closure
  xout value
endop

opcode MalInstallNamespaces(env:MalEnv):MalEnv
  root:MalEnv init MalEnvRoot(env)
  coreIndex:i = MalNsEnsure(root, "clojure.core", 1)
  userIndex:i = MalNsEnsure(root, "user", 1)
  malNamespaces[coreIndex].status = 1
  malNamespaces[userIndex].status = 1
  snapshot:MalEnv init MalEnvSnapshot(root)
  if (snapshot.length > 0) ithen
    for index in [0 ... snapshot.length - 1] do
      key:S init snapshot.keys[index]
      MalNsRegister(root, key)
      prefix:S, local:S = MalNameParts(key)
      if (strlen(prefix) == 0) ithen
        prefix init "clojure.core"
      endif
      nsIndex:i = MalNsEnsure(root, prefix, 1)
      malNamespaces[nsIndex].status = 1
      value:MalValue init snapshot.values[index]
      if (value.type == $MAL_FUNCTION_TYPE) ithen
        value.string init prefix
        root init MalEnvSet(root, key, value)
      endif
    od
  endif
  names:S[] fillarray "in-ns", "create-ns", "find-ns", "all-ns", "ns-name", \
    "ns-publics", "ns-aliases", "alias", "refer", "require", "load-file", "name", "namespace"
  for name in names do
    root init MalEnvSet(root, name, MalMkNamespaceBuiltin(name, root))
    MalNsRegister(root, name)
  od
  root init MalNsSwitch(root, "user")
  xout root
endop

opcode MalNsAlias(root:MalEnv, alias:MalValue, target:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  current:MalEnv init MalEnvResolve(root)
  if (MalNsNameValid(alias) == 0 || MalNsNameValid(target) == 0) ithen
    result init MalMkError("alias: expected two unqualified symbols")
  elseif (MalNsFind(current.id, target.string) < 0) ithen
    result init MalMkError(sprintf("alias: namespace '%s' not found", target.string))
  else
    index:i = MalNsFind(current.id, current.namespace)
    aliases:MalValue init malNamespaces[index].aliases
    existing:i = MalMapFindKey(aliases, alias)
    if (existing >= 0) ithen
      prior:MalValue init MalAt(aliases, existing + 1)
      if (strcmp(prior.string, target.string) != 0) ithen
        result init MalMkError(sprintf("alias: '%s' already refers to '%s'", alias.string, prior.string))
      endif
    endif
    if (result.type != $MAL_ERROR_TYPE) ithen
      record:MalNamespace init malNamespaces[index]
      record.aliases init MalMapAssoc(aliases, alias, target)
      malNamespaces[index] init record
    endif
  endif
  xout result
endop

opcode MalNsRefer(root:MalEnv, target:MalValue, names:MalValue):MalValue
  current:MalEnv init MalEnvResolve(root)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (MalNsNameValid(target) == 0) ithen
    result init MalMkError("refer: expected a namespace symbol")
  elseif (MalNsFind(current.id, target.string) < 0) ithen
    result init MalMkError(sprintf("refer: namespace '%s' not found", target.string))
  else
    selected:MalValue init names
    if (names.type == $MAL_KEYWORD_TYPE && strcmp(names.string, "all") == 0) ithen
      selected init MalMapKeys(MalNsPublics(current, target.string))
    endif
    if (MalIsSequential(selected) == 0) ithen
      result init MalMkError("refer: expected a vector of names or :all")
    else
      nsIndex:i = MalNsFind(current.id, current.namespace)
      refers:MalValue init malNamespaces[nsIndex].refers
      if (selected.length > 0) ithen
        for index in [0 ... selected.length - 1] do
          name:MalValue init MalAt(selected, index)
          if (MalNsNameValid(name) == 0 && MalIsSymbolNamed(name, "/") == 0) ithen
            result init MalMkError("refer: names must be unqualified symbols")
            break
          endif
          value:MalValue init MalNsQualified(current.id, target.string, name.string)
          if (value.type == $MAL_ERROR_TYPE) ithen
            result init value
            break
          endif
          qualified:S init sprintf("%s/%s", target.string, name.string)
          existing:i = MalMapFindKey(refers, name)
          if (MalEnvFind(current, sprintf("%s/%s", current.namespace, name.string)) >= 0) ithen
            result init MalMkError(sprintf("refer: '%s' already has a definition", name.string))
            break
          elseif (existing >= 0) ithen
            prior:MalValue init MalAt(refers, existing + 1)
            if (strcmp(prior.string, qualified) != 0) ithen
              result init MalMkError(sprintf("refer: '%s' already refers to another namespace", name.string))
              break
            endif
          endif
          refers init MalMapAssoc(refers, name, MalMkSymbol(qualified))
        od
      endif
      if (result.type != $MAL_ERROR_TYPE) ithen
        record:MalNamespace init malNamespaces[nsIndex]
        record.refers init refers
        malNamespaces[nsIndex] init record
      endif
    endif
  endif
  xout result
endop

opcode MalRequireSpecValid(spec:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  library:MalValue init spec
  if (spec.type == $MAL_VECTOR_TYPE && spec.length > 0) ithen
    library init MalAt(spec, 0)
    if (spec.length % 2 != 1) ithen
      result init MalMkError("require: options must be key/value pairs")
    else
      seenAlias:i = 0
      seenRefer:i = 0
      if (spec.length > 1) ithen
        for index in [0 ... (spec.length - 1) / 2 - 1] do
          option:MalValue init MalAt(spec, index * 2 + 1)
          value:MalValue init MalAt(spec, index * 2 + 2)
          if (option.type != $MAL_KEYWORD_TYPE) ithen
            result init MalMkError("require: options must be :as or :refer")
          elseif (strcmp(option.string, "as") == 0 && seenAlias == 0) ithen
            seenAlias = 1
            if (MalNsNameValid(value) == 0) ithen
              result init MalMkError("require: :as needs an unqualified symbol")
            endif
          elseif (strcmp(option.string, "refer") == 0 && seenRefer == 0) ithen
            seenRefer = 1
            if (value.type == $MAL_VECTOR_TYPE) ithen
              if (value.length > 0) ithen
                for item in [0 ... value.length - 1] do
                  symbol:MalValue init MalAt(value, item)
                  if (MalNsNameValid(symbol) == 0 && MalIsSymbolNamed(symbol, "/") == 0) ithen
                    result init MalMkError("require: :refer names must be unqualified symbols")
                  endif
                od
              endif
            elseif (value.type != $MAL_KEYWORD_TYPE || strcmp(value.string, "all") != 0) ithen
              result init MalMkError("require: :refer needs a vector or :all")
            endif
          else
            result init MalMkError("require: unsupported or repeated option")
          endif
          if (result.type == $MAL_ERROR_TYPE) ithen
            break
          endif
        od
      endif
    endif
  endif
  if (MalNsNameValid(library) == 0) ithen
    result init MalMkError("require: expected a namespace symbol or [namespace :as alias :refer [names]]")
  endif
  xout result
endop

opcode MalLoadSourceFile(root:MalEnv, path:S):MalValue
  current:MalEnv init MalEnvResolve(root)
  savedNamespace:S init current.namespace
  result:MalValue init MalMkError(sprintf("load-file: could not read %s", path))
  if (filevalid(path) == 1) ithen
    source:MalValue init MalSlurpFile(path)
    if (source.type == $MAL_ERROR_TYPE) ithen
      result init source
    else
      slash:i = strrindex(path, "/")
      directory:S init "."
      if (slash >= 0) ithen
        directory init strsub(path, 0, slash + 1)
      endif
      paths:MalValue init current.loadPaths
      present:i = 0
      if (paths.length > 0) ithen
        for index in [0 ... paths.length - 1] do
          prior:MalValue init MalAt(paths, index)
          if (strcmp(prior.string, directory) == 0) ithen
            present = 1
          endif
        od
      endif
      if (present == 0) ithen
        current.loadPaths init MalAppendValue(paths, MalMkString(directory))
        current init MalEnvStore(current)
      endif
      wrapped:S init sprintf("(do %s\nnil)", source.string)
      result, current = MalEvalSourceEnv(wrapped, current)
      ;; File-local ns changes must not change the importing caller's namespace.
      current init MalNsSwitch(current, savedNamespace)
    endif
  endif
  xout result
endop

opcode MalNsLoad(root:MalEnv, library:MalValue):MalValue
  current:MalEnv init MalEnvResolve(root)
  index:i = MalNsEnsure(current, library.string, 1)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (malNamespaces[index].status == 2 || malNamespaces[index].status == 3) ithen
    result init MalMkError(sprintf("require: circular dependency on '%s'", library.string))
  elseif (malNamespaces[index].status != 1) ithen
    relative:S init ""
    for offset in [0 ... strlen(library.string) - 1] do
      char:S init strsub(library.string, offset, offset + 1)
      if (strcmp(char, ".") == 0) ithen
        char init "/"
      elseif (strcmp(char, "-") == 0) ithen
        char init "_"
      endif
      relative strcat relative, char
    od
    relative strcat relative, ".mal"
    filename:S init ""
    paths:MalValue init current.loadPaths
    if (paths.length > 0) ithen
      for pathIndex in [0 ... paths.length - 1] do
        directory:MalValue init MalAt(paths, pathIndex)
        candidate:S init sprintf("%s/%s", directory.string, relative)
        if (filevalid(candidate) == 1) ithen
          filename init candidate
          break
        endif
      od
    endif
    if (strlen(filename) == 0) ithen
      result init MalMkError(sprintf("require: could not find %s", relative))
    else
      malNamespaces[index].status = 2
      result init MalLoadSourceFile(current, filename)
      if (result.type != $MAL_ERROR_TYPE && malNamespaces[index].status != 3) ithen
        result init MalMkError(sprintf("require: %s did not declare namespace '%s'", filename, library.string))
      endif
      if (result.type == $MAL_ERROR_TYPE) ithen
        malNamespaces[index].status = 0
      else
        malNamespaces[index].status = 1
      endif
    endif
  endif
  xout result
endop

opcode MalNsRequire(root:MalEnv, specs:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (specs.length > 0) ithen
    for index in [0 ... specs.length - 1] do
      result init MalRequireSpecValid(MalAt(specs, index))
      if (result.type == $MAL_ERROR_TYPE) ithen
        break
      endif
    od
    if (result.type != $MAL_ERROR_TYPE) ithen
      for index in [0 ... specs.length - 1] do
        spec:MalValue init MalAt(specs, index)
        library:MalValue init spec
        if (spec.type == $MAL_VECTOR_TYPE) ithen
          library init MalAt(spec, 0)
        endif
        result init MalNsLoad(root, library)
        if (result.type == $MAL_ERROR_TYPE) ithen
          break
        endif
        if (spec.type == $MAL_VECTOR_TYPE && spec.length > 1) ithen
          for optionIndex in [0 ... (spec.length - 1) / 2 - 1] do
            option:MalValue init MalAt(spec, optionIndex * 2 + 1)
            value:MalValue init MalAt(spec, optionIndex * 2 + 2)
            if (strcmp(option.string, "as") == 0) ithen
              result init MalNsAlias(root, value, library)
            else
              result init MalNsRefer(root, library, value)
            endif
            if (result.type == $MAL_ERROR_TYPE) ithen
              break
            endif
          od
        endif
        if (result.type == $MAL_ERROR_TYPE) ithen
          break
        endif
      od
    endif
  endif
  xout result
endop

opcode MalEvalNamespace(ast:MalValue, env:MalEnv):MalValue
  root:MalEnv init MalEnvRoot(env)
  result:MalValue init MalMkError("ns: expected an unqualified namespace symbol")
  if (strlen(root.namespace) == 0) ithen
    result init MalMkError("ns: use a Step A or Csound environment")
  elseif (ast.length >= 2) ithen
    name:MalValue init MalAt(ast, 1)
    if (MalNsNameValid(name) == 1) ithen
      specs:MalValue init MalMkValue($MAL_LIST_TYPE)
      result init MalMkValue($MAL_NIL_TYPE)
      if (ast.length > 2) ithen
        for index in [2 ... ast.length - 1] do
          clause:MalValue init MalAt(ast, index)
          if (clause.type != $MAL_LIST_TYPE || clause.length < 1) ithen
            result init MalMkError("ns: expected (:require ...) clauses")
            break
          endif
          head:MalValue init MalAt(clause, 0)
          if (head.type != $MAL_KEYWORD_TYPE || strcmp(head.string, "require") != 0) ithen
            result init MalMkError("ns: only :require clauses are supported")
            break
          endif
          if (clause.length > 1) ithen
            for item in [1 ... clause.length - 1] do
              spec:MalValue init MalAt(clause, item)
              result init MalRequireSpecValid(spec)
              if (result.type == $MAL_ERROR_TYPE) ithen
                break
              endif
              specs init MalAppendValue(specs, spec)
            od
          endif
          if (result.type == $MAL_ERROR_TYPE) ithen
            break
          endif
        od
      endif
      if (result.type != $MAL_ERROR_TYPE) ithen
        previous:S init root.namespace
        nsIndex:i = MalNsEnsure(root, name.string, 1)
        previousStatus:i = malNamespaces[nsIndex].status
        previousCore:i = malNamespaces[nsIndex].core
        malNamespaces[nsIndex].core = 1
        if (malNamespaces[nsIndex].status == 2) ithen
          malNamespaces[nsIndex].status = 3
        elseif (malNamespaces[nsIndex].status != 3) ithen
          malNamespaces[nsIndex].status = 1
        endif
        root init MalNsSwitch(root, name.string)
        result init MalNsRequire(root, specs)
        if (result.type == $MAL_ERROR_TYPE) ithen
          malNamespaces[nsIndex].status = previousStatus
          malNamespaces[nsIndex].core = previousCore
          root init MalNsSwitch(root, previous)
        endif
      endif
    endif
  endif
  xout result
endop

opcode MalApplyNamespaceBuiltin(fn:MalValue, args:MalValue):MalValue
  root:MalEnv init MalEnvRoot(fn.env[0])
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  name:S init fn.string
  if (strcmp(name, "require") == 0) ithen
    result init MalNsRequire(root, args)
  elseif (strcmp(name, "all-ns") == 0) ithen
    if (args.length != 0) ithen
      result init MalMkError("all-ns: expected no arguments")
    else
      result init MalMkValue($MAL_LIST_TYPE)
      if (malNamespaceCount > 0) ithen
        for index in [0 ... malNamespaceCount - 1] do
          if (malNamespaces[index].owner == root.id) ithen
            result init MalAppendValue(result, MalMkSymbol(malNamespaces[index].name))
          endif
        od
      endif
    endif
  elseif (strcmp(name, "alias") == 0) ithen
    if (args.length != 2) ithen
      result init MalMkError("alias: expected two arguments")
    else
      result init MalNsAlias(root, MalAt(args, 0), MalAt(args, 1))
    endif
  elseif (strcmp(name, "refer") == 0) ithen
    if (args.length == 1) ithen
      result init MalNsRefer(root, MalAt(args, 0), MalMkKeyword("all"))
    elseif (args.length == 3) ithen
      option:MalValue init MalAt(args, 1)
      names:MalValue init MalAt(args, 2)
      if (option.type == $MAL_KEYWORD_TYPE && strcmp(option.string, "only") == 0 && names.type == $MAL_VECTOR_TYPE) ithen
        result init MalNsRefer(root, MalAt(args, 0), names)
      else
        result init MalMkError("refer: expected :only [names]")
      endif
    else
      result init MalMkError("refer: expected a namespace and optional :only [names]")
    endif
  elseif (args.length != 1) ithen
    result init MalMkError(sprintf("%s: expected one argument", name))
  else
    value:MalValue init MalAt(args, 0)
    if (strcmp(name, "name") == 0 || strcmp(name, "namespace") == 0) ithen
      if (value.type == $MAL_STRING_TYPE && strcmp(name, "name") == 0) ithen
        result init value
      elseif (value.type != $MAL_SYMBOL_TYPE && value.type != $MAL_KEYWORD_TYPE) ithen
        result init MalMkError(sprintf("%s: expected a symbol or keyword", name))
      else
        prefix:S, local:S = MalNameParts(value.string)
        if (strcmp(name, "name") == 0) ithen
          result init MalMkString(local)
        elseif (strlen(prefix) > 0) ithen
          result init MalMkString(prefix)
        endif
      endif
    elseif (strcmp(name, "load-file") == 0) ithen
      if (value.type != $MAL_STRING_TYPE) ithen
        result init MalMkError("load-file: expected a filename string")
      else
        result init MalLoadSourceFile(root, value.string)
      endif
    elseif (MalNsNameValid(value) == 0) ithen
      result init MalMkError(sprintf("%s: expected an unqualified namespace symbol", name))
    elseif (strcmp(name, "create-ns") == 0 || strcmp(name, "in-ns") == 0) ithen
      nsIndex:i = MalNsEnsure(root, value.string, 0)
      if (strcmp(name, "in-ns") == 0) ithen
        root init MalNsSwitch(root, value.string)
      endif
      result init value
    else
      nsIndex:i = MalNsFind(root.id, value.string)
      if (strcmp(name, "find-ns") == 0) ithen
        if (nsIndex >= 0) ithen
          result init value
        endif
      elseif (nsIndex < 0) ithen
        result init MalMkError(sprintf("%s: namespace '%s' not found", name, value.string))
      elseif (strcmp(name, "ns-name") == 0) ithen
        result init value
      elseif (strcmp(name, "ns-publics") == 0) ithen
        result init MalNsPublics(root, value.string)
      elseif (strcmp(name, "ns-aliases") == 0) ithen
        result init malNamespaces[nsIndex].aliases
      endif
    endif
  endif
  xout result
endop
