# Live MAL in the Web-IDE

Build the include from the repository root:

```sh
python3 tools/bundle.py --output dist/mal.inc
```

Create a Web-IDE project with these three files at its root:

- `project.csd` from this directory
- `live.clj` from this directory
- `mal.inc` from `dist/`

Start `project.csd`. It stays running silently until you schedule a note.
Open `live.clj` and use Cmd/Ctrl+Shift+Enter to evaluate the file, or select
forms and press Cmd/Ctrl+E. Results appear in the Csound console. A successful
evaluation flashes the selected text; an error flashes it red.

The host defines the IDE's generic `LispEval(source:S):i` hook. It keeps one
MAL environment between calls and passes source to `MalEvalFormsEnv`. That
opcode reads all forms, evaluates them in order, and returns the last value
and the updated environment. Empty text and comments return `nil`. Reader
errors prevent evaluation; an evaluation error stops later forms but keeps
earlier definitions. Restarting playback starts a new session.

WebMCP uses the same hook. Call `csound_read_workspace` for document IDs,
then `csound_play` with the CSD document ID. Read `live.clj` with
`csound_read_document`, and pass its `document_id` and `revision` as
`base_revision` to `csound_evaluate_region`, with `from` and `to` offsets.
Read results with `csound_read_console`. `csound_type_text` can add forms
before evaluation. Offsets count UTF-16 characters and `to` is exclusive.
