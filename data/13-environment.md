<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 13: Environment Configuration

This section is the canonical reference for environment variables read by the `bcs` toolchain itself. Unlike sections 01–12, it documents the toolkit's runtime configuration surface — not coding rules — and contributes no `BCS####` codes to `bcs codes`. For the same reason `bcs check` leaves this section out of the copy of the standard it shows the checker; `bcs display` and `bcs generate` keep it.

Variables fall into six families:

1. **User configuration** — defaults for `bcs check` flags, overridable per-call
2. **Model aliases** — the `MODEL_ALIASES` map: short names that expand to canonical model IDs
3. **Backend selection** — `OLLAMA_HOST`, `BCS_OLLAMA_NUM_CTX` and `BCS_OLLAMA_KEEP_ALIVE` configure the local Ollama backend
4. **Credentials** — API keys consumed by the cloud backends
5. **Search paths** — XDG locations for config and state files, plus the `BCS_CONF_DIR` test override
6. **Internal / advanced** — runtime flags exported by `bcs` itself; documented for source-readers

Values are resolved in this precedence (highest wins):

1. CLI flag (e.g. `-m`, `-e`, `--strict`)
2. Configuration file (`bcs.conf` cascade, see §13.5)
3. Environment variable
4. Hardcoded default in `bcs`

The `bcs.conf.sample` file in the source tree is a quick-start template. This section is the authoritative reference.

## 13.1 User Configuration

Default values for the `bcs check` subcommand. All have CLI flag equivalents that override them.

### `BCS_MODEL`

- **Default:** `sonnet` (alias for `claude-sonnet-4-6`)
- **Values:** a `MODEL_ALIASES` short name (e.g. `sonnet`, `opus`, `haiku`, `flash`, `gpt5`, `qwen`), `claude-code[:alias|:model]`, or any concrete model name routed by `_sniff_backend()` (`claude-*` → Anthropic, `gemini-*` → Google, `gpt-*`/`o[0-9]*` → OpenAI, anything else → Ollama)
- **Override flag:** `-m`, `--model`
- **Consumed:** `cmd_check()` initialiser

The backend is resolved entirely from the (alias-expanded) model name — there is no probe and no separate backend flag. The legacy tier keywords (`fast`, `balanced`, `thorough`) are rejected with exit 22 and a migration hint pointing at the alias map.

### `BCS_EFFORT`

- **Default:** `medium`
- **Values:** `low` (or `min`), `medium`, `high`, `xhigh`, `max`
- **Override flag:** `-e`, `--effort`
- **Consumed:** `cmd_check()` initialiser

Effort controls both prompt guidance and the output token budget (`EFFORT_TOKENS` array: `low=4000`, `medium=8000`, `high=24000`, `xhigh=40000`, `max=64000`). `min` is normalised to `low` at parse time. `max` should be avoided for Ollama cloud models (hallucination risk). `medium` is the default on evidence: `low` sends no thinking budget (`reasoning_effort=minimal` on OpenAI), which is fast and accurate on short scripts but raised false `[ERROR]` findings on a compliant real-size script in every measured run. Do not gate a build on `low`. Effort has no effect on the Claude Code CLI backend, which always runs at the CLI's lowest native effort: the CLI turns its own effort level into a thinking budget, and `medium` there cost 8-12 times the wall time of an API backend for no measured gain.

### `BCS_STRICT`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-s` / `-S`, `--strict` / `--no-strict`
- **Consumed:** `cmd_check()` initialiser

When `1`, warnings are reported as violations and contribute to a non-zero exit code.

### `BCS_DEBUG`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-D`, `--debug`
- **Consumed:** `cmd_check()` initialiser

When `1`, the raw-response dump path is announced on success (it is always announced on failure).

### `BCS_JSON`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-j`, `--json`
- **Consumed:** `cmd_check()` initialiser

When `1`, stdout is a single JSON object shaped like `shellcheck --format=json1` (`{source, meta, comments[]}`). Info messages still go to stderr when verbose.

### `BCS_SHELLCHECK`

- **Default:** `1` (enabled)
- **Values:** `0` or `1`
- **Override flag:** `--shellcheck`, `--no-shellcheck`
- **Consumed:** `cmd_check()` initialiser

When `1`, `shellcheck --format=json -x` runs over the target script and the JSON report is prepended to the LLM user prompt as static-analysis context. Auto-skipped when `shellcheck` is not on `PATH`.

### `BCS_TIER`

- **Default:** unset (no tier filter)
- **Values:** `core`, `recommended`, or `style`
- **Override flag:** `-T`, `--tier`
- **Consumed:** `cmd_check()` initialiser

Restricts findings to a single tier. Useful in CI: `BCS_TIER=core` reports only correctness/safety bugs. Any other value is refused with exit 22, whether it comes from this variable, `bcs.conf` or `-T`: a filter that names no tier would match no finding.

### `BCS_MIN_TIER`

- **Default:** unset (no minimum)
- **Values:** `core`, `recommended`, or `style`
- **Override flag:** `-M`, `--min-tier`
- **Consumed:** `cmd_check()` initialiser

Reports findings at the named tier or higher severity. `BCS_MIN_TIER=recommended` skips style findings during development. Any other value is refused with exit 22.

### `BCS_RESPONSE_DUMP`

- **Default:** `${XDG_STATE_HOME:-$HOME/.local/state}/bcs/last-response.txt`, or `mktemp /tmp/bcs-last-response.XXXXXX` if the state directory cannot be created
- **Values:** any writable file path
- **Override flag:** none (set externally to redirect)
- **Consumed:** `cmd_check()` always exports this; `_dump_response()` writes raw HTTP bodies; the path is announced on failure or with `--debug`

Set externally to direct raw API responses to a known location for inspection. The Claude Code CLI backend returns text, not JSON, so for that backend the file holds the CLI's standard error: an authentication or quota failure is diagnosed from here.

## 13.2 Model Aliases

The four legacy per-backend overrides (`BCS_ANTHROPIC_MODEL`, `BCS_OPENAI_MODEL`, `BCS_GOOGLE_MODEL`, `BCS_OLLAMA_MODEL`) and the tier-keyword arrays (`*_MODELS`) are gone. The single mechanism for naming models is the `MODEL_ALIASES` associative array.

### `MODEL_ALIASES`

- **Default:** built-in map in `bcs` (`opus`, `sonnet`, `haiku`, `flash`, `pro`, `flash-lite`, `gpt5`, `gpt5-mini`, `qwen`, `qwen-small`)
- **Values:** `MODEL_ALIASES[name]=canonical-id` entries, set in `bcs.conf` (it is a Bash associative array, so it can only be extended from a sourced config file — not from the environment)
- **Consumed:** `_expand_alias()` before `_sniff_backend()` routing

Extend or override in `bcs.conf`:

```bash
MODEL_ALIASES[mymodel]=qwen3.5:14b
MODEL_ALIASES[sonnet]=claude-sonnet-4-7   # repoint a built-in alias
```

Unknown names pass through `_expand_alias()` unchanged, so canonical model IDs need no alias entry. To pin a model across sessions, set `BCS_MODEL` to an alias or canonical ID in `bcs.conf`.

## 13.3 Backend Selection (Ollama)

### `OLLAMA_HOST`

- **Default:** `localhost:11434`
- **Values:** `host:port` or `protocol://host:port`
- **Consumed:** `_llm_ollama()`

Direct the local Ollama backend at a non-default endpoint (e.g. `OLLAMA_HOST=ollama.lan:11434`).

### `BCS_OLLAMA_NUM_CTX`

- **Default:** `40960`
- **Values:** a positive integer (tokens); anything else is exit 22
- **Consumed:** `_llm_ollama()` → `options.num_ctx`

Ollama truncates the prompt to the server default (4096 tokens) unless the request carries `options.num_ctx`. The standard alone is about 33k tokens, so without this field the model never sees the rules and returns nothing useful. The value must hold the standard plus the script plus the reply: raise it for long scripts or `-e high` and above, at the cost of VRAM. `bcs check` warns when the prompt is certain to exceed the configured window.

### `BCS_OLLAMA_KEEP_ALIVE`

- **Default:** `30m`
- **Values:** a duration string (`30m`, `1h`) or seconds as an integer (`-1` = keep forever, `0` = unload at once); integers are sent as JSON numbers
- **Consumed:** `_llm_ollama()` → top-level `keep_alive`

Keeps the model loaded between checks so a batch run does not pay the model load on every file.

## 13.4 Credentials

API keys for the cloud backends. There is no key probe: the backend (and therefore which key is needed) is determined solely by the alias-expanded model name. All keys are passed to `curl` via a `--config` file descriptor, never on the command line, so they are not visible in `ps`.

### `ANTHROPIC_API_KEY`

- **Required for:** Anthropic API backend (`claude-*` models). The `claude-code` sentinel requires the Claude Code CLI binary instead (missing CLI is exit 18, not an API fallback) and unsets `ANTHROPIC_API_KEY` for the CLI invocation so it authenticates via OAuth.
- **Consumed:** `_llm_anthropic()` `x-api-key` header

### `OPENAI_API_KEY`

- **Required for:** OpenAI API backend (`gpt-*`, `o[0-9]*` models)
- **Consumed:** `_llm_openai()` `Authorization: Bearer` header

### `GOOGLE_API_KEY`

- **Required for:** Google Gemini API backend (`gemini-*` models)
- **Consumed:** `_llm_google()` `x-goog-api-key` header

### `GEMINI_API_KEY`

- **Alias for:** `GOOGLE_API_KEY` (Google's two SDK families use different names for the same key)
- **Precedence:** `GOOGLE_API_KEY` wins. If both are set, `bcs` unsets `GEMINI_API_KEY` before invoking the backend so downstream tooling sees a single canonical name.

## 13.5 Search Paths

XDG Base Directory variables that locate `bcs.conf` and the response dump. Standard XDG semantics apply (defaults used when unset).

### `XDG_CONFIG_HOME`

- **Default:** `$HOME/.config`
- **Affects:** `bcs.conf` and `policy.conf` cascade — `$XDG_CONFIG_HOME/bcs/bcs.conf` is the user-level config layer (overrides `/etc/bcs.conf`, `/etc/bcs/bcs.conf`, `/usr/local/etc/bcs/bcs.conf`)
- **Consumed:** `_conf_search_paths()`; policy resolution in `_load_policy()`

### `XDG_STATE_HOME`

- **Default:** `$HOME/.local/state`
- **Affects:** default `BCS_RESPONSE_DUMP` location (`$XDG_STATE_HOME/bcs/last-response.txt`)
- **Consumed:** `cmd_check()` state-dir setup

### `BCS_CONF_DIR`

- **Default:** unset (full cascade in effect)
- **Values:** a directory path; when set, `$BCS_CONF_DIR/bcs.conf` becomes the **only** config file considered, replacing the entire cascade
- **Consumed:** `_conf_search_paths()`

Intended for hermetic testing — it prevents a real `/etc/bcs.conf` or `~/.config/bcs/bcs.conf` from leaking into a test run. The test harness (`tests/test-helpers.sh`) sets it to an empty directory by default.

The data directory containing `BASH-CODING-STANDARD.md` and `data/*.md` section files is **not** XDG-resolved. It uses a four-step FHS search (development tree → relative `share/yatti/BCS/data` → `/usr/local/share/yatti/BCS/data` → `/usr/share/yatti/BCS/data`) defined in `_find_data_dir()`. There is no environment override for the data directory.

## 13.6 Internal / Advanced

These variables are set by `bcs` itself at runtime. They are documented here so power users reading the source — or wrapping the `_llm_*` backend functions — understand the runtime contract. **Users should not set them directly**; the corresponding CLI flag is the supported interface.

### `BCS_JSON_MODE`

- **Set by:** `cmd_check()` exports this from `--json` / `BCS_JSON`
- **Values:** `0` or `1`
- **Consumed:** all four `_llm_*` backend bodies

When `1`, each backend flips its native JSON-output knob:

- Ollama → `"format": "json"` at payload top level
- OpenAI → `"response_format": {"type": "json_object"}`
- Google → `"response_mime_type": "application/json"` under `generationConfig`
- Anthropic / Claude CLI → no native flag; rely on prompt discipline plus `_strip_json_fences()` fallback

Override the flag via `-j`/`--json` or `BCS_JSON=1` rather than setting `BCS_JSON_MODE` directly. Setting it externally without taking the rest of the JSON-rendering path (envelope wrap, schema validation in `_render_json_output()`) produces inconsistent output.
