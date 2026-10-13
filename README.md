# deepwiki-scraper-cli

V CLI that downloads any repo's full wiki from [DeepWiki](https://deepwiki.com)
via MCP and builds a single offline PDF. No runtime: one static binary.

## Install

- [V](https://vlang.io), plus `pandoc` + `typst` on PATH for PDFs
  (Arch: `pandoc-bin`, not `pandoc-cli` — the latter conflicts and pulls ~675MB of GHC deps)
- Or grab `deepwiki` / `deepwiki-chimera` (musl, for Chimera Linux) from
  [Releases](https://github.com/SrDicov/deepwiki-scraper-cli/releases)

## Build

```
v -prod -o deepwiki .   # glibc
v test .                # 19 tests
```

Chimera/musl static: `v -cc musl-gcc -cflags "-static" -gc none -d musl -prod -o deepwiki-chimera .`

## Use

```
./deepwiki <user/repo | GitHub URL | DeepWiki URL>
./deepwiki sindresorhus/is                     # creates is.txt + is.pdf
./deepwiki sindresorhus/is --output manual.pdf # stdout + PDF there
./deepwiki - < wiki.md | wc -c                 # stdin filter, no files
```

No `--output`: saves `<repo>.txt` (always first) and `<repo>.pdf`, stdout
stays silent. `-` reads markdown from stdin (pipes and redirects).

Env: `DEEPWIKI_RETRY_DELAY` (ms, 250), `DEEPWIKI_MAX_RETRIES` (3), `TMPDIR`.
Retries on 429, 502–504, network errors and JSON-RPC errors.

## License

GPL-3.0 — see [LICENSE](LICENSE). By Dicov.
