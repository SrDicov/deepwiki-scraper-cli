# AGENTS.md — deepwiki-scraper-cli

## Commands

- Run: `npx tsx src/index.ts <user/repo> [--output <file.pdf>] [--lang <idioma>]`
- Shortcut: `./start.sh <user/repo | GitHub URL | DeepWiki URL> [--lang <idioma>]` → saves `<repo>.txt` + `<repo>.pdf`
- Typecheck: `npx tsc --noEmit` (no `npm run` scripts, no build step, no lint/test framework)
- Setup: `npm install` (provides `tsx`, `typescript`); PDF also needs `pandoc` + `typst` binaries on PATH

## Toolchain

- Node.js >= 18 (uses global `fetch`).
- TypeScript ESM (`"type": "module"`, `tsconfig.module: "nodenext"`); imports must use explicit `.js` extensions (`verbatimModuleSyntax`).
- Strict `tsconfig`: `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `isolatedModules`. Run `npx tsx` directly, never `ts-node`/`tsc` emit.

## Environment

- `DEEPWIKI_RETRY_DELAY` (ms, default `250`), `DEEPWIKI_MAX_RETRIES` (default `3`)
- `OPENROUTER_API_KEY` — required only when `--lang` is passed

## Gotchas (verify before changing)

- `src/index.ts`: arg parsing is positional/minimal — first non-dash arg is repo; `--output`/`--lang` blindly take the next arg. `deepwiki.md` is written before PDF, so a failed PDF run still overwrites it.
- `src/resilience.ts`: only the MCP fetch is retried, on 429 / 502–504 / status-less network errors. JSON-RPC `data.error` and `SyntaxError` (bad SSE JSON) never retry. Translation calls (`src/translator.ts`) have no retry.
- `src/index.ts`: splits markdown on `(?=# Page: )` and translates pages in parallel via `Promise.all` (OpenRouter `stealth/ox-alpha` in `src/translator.ts`); one page failure aborts the whole run.
- `src/pdf-generator.ts`: invokes `pandoc -f markdown-citations-yaml_metadata_block --pdf-engine=typst` — both extensions are load-bearing (`citations` avoids `#cite(...)` Typst aborts; `-yaml_metadata_block` stops `---\n**Sources:**\n...\n---` page separators being parsed as YAML frontmatter). It pre-strips empty/internal `[..](#..)` links in a loop to fixpoint (nested `[[a]() , b]()` needs >1 pass), and unwraps `<details><summary>` to `**title** + body`. `consolidated.md` is deleted only on success — on failure it is left in CWD for debugging.
- Outputs are CWD-relative: `deepwiki.md` (overwritten each run, gitignored), `consolidated.md` (temp), `*.pdf` + `*.txt` (gitignored; `start.sh` names them `<repo>.pdf`/`<repo>.txt`).

## Architecture

- `start.sh` — wrapper: normalizes arg to `user/repo` → runs CLI with `--output <repo>.pdf` → copies `deepwiki.md` to `<repo>.txt`
- `src/index.ts` — CLI entry: fetch wiki → optional translate → write `deepwiki.md` → optional PDF
- `src/mcp-client.ts` — JSON-RPC `tools/call` to `https://mcp.deepwiki.com/mcp` with `Accept: application/json, text/event-stream`; SSE payload extracted from the `data: ` line
- `src/resilience.ts` — exponential backoff (`DELAY * 2^attempt`) + up to 100ms jitter
- `src/pdf-generator.ts` — sanitize + spawn `pandoc`
- `src/translator.ts` — OpenRouter chat completions per page

## Notes

- All user-facing strings are in Spanish.
- Single-package repo, no monorepo, no CI.
