// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Exercise the example host with the same WebAssembly engine as the Web-IDE.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const browserModule = process.argv[2];
if (!browserModule) {
  throw new Error(
    "Usage: node tests/check-web-ide.mjs /path/to/@csound/browser/dist/csound.js",
  );
}
globalThis.self = globalThis;
globalThis.window = globalThis;
const { libcsound } = await import(pathToFileURL(resolve(browserModule)));
const api = await libcsound();
const csound = api.csoundCreate();
const bundle = await readFile(
  new URL("../dist/mal.inc", import.meta.url),
  "utf8",
);
const project = await readFile(
  new URL("../examples/web-ide/project.csd", import.meta.url),
  "utf8",
);
const orchestra = project
  .match(/<CsInstruments>([\s\S]*?)<\/CsInstruments>/)[1]
  .replace('#include "mal.inc"', () => bundle);

function evaluate(source, expected = 1) {
  api.csoundSetStringChannel(csound, "__web_ide_lisp_source", source);
  const result = api.csoundEvalCode(
    csound,
    'return (LispEval(chnget:S("__web_ide_lisp_source")) == 0 ? 1 : -1)\n',
  );
  assert.equal(result, expected, source);
}

try {
  for (const option of ["-n", "-d", "-m0", "--daemon"]) {
    api.csoundSetOption(csound, option);
  }
  assert.equal(
    api.csoundCompileOrc(csound, orchestra),
    0,
    "compile example host",
  );
  assert.equal(api.csoundStart(csound), 0, "start the live session");
  evaluate(
    "(ns live) (def counter (atom 0)) (defn tick! [] (swap! counter inc))",
  );
  evaluate("(tick!) @counter");
  evaluate(
    '(if (= @counter 1) (println "PASS: one increment") (throw "wrong counter"))',
  );
  evaluate('(def message "hélló $MACRO {{ }}") (println message)');
  evaluate(") (reset! counter 99)", -1);
  evaluate("missing-name (reset! counter 99)", -1);
  evaluate(
    '(if (= @counter 1) (println "PASS: recovery") (throw "lost state"))',
  );
  // A callback suspends and resumes through several frame constructors.
  const job = api.csoundEvalCode(
    csound,
    'return MalEvalJobStart(read_str("(map inc [1 2 3])"), malLiveEnv)\n',
  );
  assert.ok(job > 0, "create an evaluation job");
  let status = 0;
  let steps = 0;
  while (status === 0 && steps < 1000) {
    status = api.csoundEvalCode(csound, `return MalEvalJobStep(${job}, 1)\n`);
    steps += 1;
  }
  assert.equal(status, 1, "finish the evaluation job");
  assert.ok(steps > 1, "yield between evaluation steps");
  assert.equal(
    api.csoundEvalCode(
      csound,
      `return (strcmp(pr_str(MalEvalJobResult(${job})), "(2 3 4)") == 0 ? 1 : -1)\n`,
    ),
    1,
    "preserve callback results between steps",
  );
  assert.equal(
    api.csoundEvalCode(
      csound,
      `MalEvalJobCancel(${job})\nreturn MalEvalJobStep(${job}, 1)\n`,
    ),
    -1,
    "release the completed job",
  );
  const source = await readFile(
    new URL("../examples/web-ide/live.clj", import.meta.url),
    "utf8",
  );
  evaluate(source);
  for (let block = 0; block < 300; block++) api.csoundPerformKsmps(csound);
  evaluate(
    '(if (= @counter 1) (println "PASS: Web-IDE file and session") (throw "repeated evaluation"))',
  );
  console.log(
    "PASS: browser engine, multi-form regions, atoms, jobs, errors, and instruments",
  );
} finally {
  api.csoundDestroy(csound);
}
