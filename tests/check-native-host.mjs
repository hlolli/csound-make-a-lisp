// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const [modulePath, bundlePath] = process.argv.slice(2);
if (!modulePath || !bundlePath) {
  throw new Error("Usage: node tests/check-native-host.mjs /path/to/csound.js /path/to/mal.inc");
}
Object.assign(globalThis, { self: globalThis, window: globalThis });
const { libcsound } = await import(pathToFileURL(resolve(modulePath)));
const api = await libcsound();
const engine = api.csoundCreate();
try {
  const bundle = await readFile(bundlePath, "utf8");
  const fixture = await readFile(new URL("native.orc", import.meta.url), "utf8");
  // Native exitnow(0) ends the process. In Wasm, report success through a
  // channel; failed assertions still abort the test with exitnow(1).
  const source = fixture.replace('#include "src/main.orc"', () => bundle)
    .replace("exitnow(0)", 'chnset 1, "__native_test_passed"');
  for (const flag of ["-n", "-d", "-m0", "--daemon"]) api.csoundSetOption(engine, flag);
  assert.equal(api.csoundCompileOrc(engine, source), 0);
  assert.equal(api.csoundStart(engine), 0);
  api.csoundPerformKsmps(engine);
  assert.equal(api.csoundGetControlChannel(engine, "__native_test_passed"), 1);
  console.log("PASS: Wasm native host calls reuse storage across 150 calls with an 8 MiB scratch array.");
} finally {
  api.csoundDestroy(engine);
}
