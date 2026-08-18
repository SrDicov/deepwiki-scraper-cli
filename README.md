# DeepWiki Scrapper CLI

A TypeScript CLI that downloads the full documentation of any repository from [DeepWiki](https://deepwiki.com) through its MCP API and compiles it into a single offline, navigable PDF.

## Features

- Fetches the entire wiki (all pages) in a single JSON-RPC call over MCP (`https://mcp.deepwiki.com/mcp`)
- Stores the raw markdown in `deepwiki.md` (persistent store, overwritten on each run)
- Generates the PDF with Pandoc + Typst
- Exponential backoff with jitter for rate limits and network errors

## Requirements

- Node.js >= 18 (global `fetch`)
- [Pandoc](https://pandoc.org) and [Typst](https://typst.app) binaries on PATH

## Install

```
npm install
```

## Usage

```
npx tsx src/index.ts <user/repo> [--output <file.pdf>]
```

Examples:

```
npx tsx src/index.ts sindresorhus/is --output manual.pdf   # download + PDF
npx tsx src/index.ts sindresorhus/is                       # download only
```

Outputs (CWD-relative): `deepwiki.md` (markdown store), `consolidated.md` (temp, deleted on success), the PDF.

Environment variables: `DEEPWIKI_RETRY_DELAY` (ms, default 250), `DEEPWIKI_MAX_RETRIES` (default 3). Retries on HTTP 429, 502–504, and network errors.

## Architecture

- `src/index.ts` — CLI entry point: fetch + optional PDF
- `src/mcp-client.ts` — JSON-RPC client for the DeepWiki MCP endpoint (SSE parsing)
- `src/resilience.ts` — exponential backoff wrapper
- `src/pdf-generator.ts` — markdown to PDF via Pandoc/Typst; strips links and citations that would break Typst

## License

GPL-3.0 — see [LICENSE](LICENSE).

## Credits

Developed by Dicov.
