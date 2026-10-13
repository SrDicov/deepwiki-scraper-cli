# AGENTS.md — deepwiki-scraper-cli (CLI en V, filosofía UNIX/POSIX)

## Commands

- Build: `v -prod -o deepwiki .` (solo stdlib; `v test .` = 19 tests)
- Chimera: `v -cc musl-gcc -cflags "-static" -gc none -d musl -prod -o deepwiki-chimera .`
- Run: `./deepwiki <user/repo|URL|-> [--output <pdf>]`
- CI: push/PR → tests + ambos binarios (artefactos); tag `v*` → Release.
- Ramas: `main` + `testing`. Releases: tag `vX.Y.Z` (`gh release view`).

## Toolchain

- V, sin Node/npm. Solo `os`, `net.http`, `json`, `time` (sin módulo regex:
  el saneador es un parser manual porque V/regex no tiene lookahead).
- Env: `DEEPWIKI_RETRY_DELAY` (250), `DEEPWIKI_MAX_RETRIES` (3), `TMPDIR`.
  Sin ficheros de config. Strings de usuario en español.

## Gotchas (verificados, no romper)

- `main.v`: sin `--output` escribe `<repo>.txt` PRIMERO y luego `<repo>.pdf`,
  stdout en silencio; `--output` explícito = stdout + PDF (filtro); `-` =
  stdin sin ficheros. Exit 1 siempre. Sin `--lang` (traducción eliminada).
- `main.v` `normalize_slug()`: réplica 1:1 del viejo `start.sh` (32 casos
  contra sh, incluidos `a/b/c`→`a/b` y `HTTPS://…`→error).
- `mcp_client.v`: errores de herramienta llegan como `content[0].text` con
  `isError` (verificado en vivo) → `E_TOOL` fatal. Reintento: 429/502–504,
  red, `data.error`; nunca JSON roto.
- `sanitize.v`: réplica exacta del motor de la regex JS (anclaje en `[`,
  greedy); byte-idéntico en 34 casos adversariales+reales. OJO V 0.5:
  single-quote SÍ interpreta escapes y el backtick es delimitador de rune
  en todas partes (rompe el lexer dentro de strings).
- `pdf_generator.v`: flags pandoc `-f markdown-citations-yaml_metadata_block
  --pdf-engine=typst -V mainfont='Libertinus Serif'` (los 3 load-bearing);
  temporal en `TMPDIR`, se conserva al fallo.
- Builds musl: `-d musl` obligatorio con `-cc` custom (si no, falla
  `backtrace_symbols`); `-gc none` (Boehm no enlaza estático con musl);
  jamás heredar `CPATH` de glibc.
- TLS sin verificar (hallazgo abierto): V http usa `VERIFY_OPTIONAL` sin CA
  → cifrado sin autenticación. Fix: `validate`+`verify` en `FetchConfig`
  con bundle CA por rutas; requiere toolchain para verificarlo.

## Layout

- `main.v`, `mcp_client.v`, `resilience.v`, `sanitize.v`, `pdf_generator.v`,
  `deepwiki_test.v`, `v.mod`, `.github/workflows/build.yml` (+job release).
