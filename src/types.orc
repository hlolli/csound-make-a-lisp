;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

struct MalValue type:i, number:i, string:S, list:MalValue[], env:MalEnv[], metadata:MalValue[], length:i, isMacro:i, astRef:i

struct MalTokens length:i, tokens:S[]

struct MalReader peek:S, position:i, length:i, done:i

struct MalReadResult value:MalValue, reader:MalReader

struct MalEnv keys:S[], values:MalValue[], outer:MalEnv[], length:i, id:i, persistent:i

struct MalCsoundRender statements:S, expression:S, outputs:i, error:S

malEmptyValues@global:MalValue[] init 0
malEmptyEnvs@global:MalEnv[] init 0
malEmptyStrings@global:S[] init 0
malAtomValues@global:MalValue[] init 0
malAtomCount@global:i init 0
malReducedCount@global:i init 0
malGensymCount@global:i init 0
malFunctionDefinitions@global:MalValue[] init 0
malFunctionCount@global:i init 0
malAstNodes@global:MalValue[] init 0
malAstNodeCount@global:i init 0
malReaderTokens@global:S[] init 0
malCsoundTemporaryCount@global:i init 0

malCsoundNodeCount@global:i init 0
malCsoundCacheIds@global:i[] init 0
malCsoundCacheValues@global:MalCsoundRender[] init 0
malCsoundCacheCount@global:i init 0
