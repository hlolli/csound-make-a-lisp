struct MalValue type:i, number:i, string:S, list:MalValue[], env:MalEnv[], length:i

struct MalTokens length:i, tokens:S[]

struct MalReader peek:S, position:i, tokens:S[], length:i, done:i

struct MalReadResult type:i, number:i, string:S, list:MalValue[], env:MalEnv[], length:i, readerPeek:S, readerPosition:i, readerTokens:S[], readerLength:i, readerDone:i

struct MalEnv keys:S[], values:MalValue[], outer:MalEnv[], length:i
