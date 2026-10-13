# deepwiki-scraper-cli

CLI en V que descarga la wiki completa de cualquier repo desde
[DeepWiki](https://deepwiki.com) vía MCP y genera un único PDF offline.
Sin runtime: un solo binario estático.

## Instalar

- [V](https://vlang.io), más `pandoc` + `typst` en el PATH para los PDF
  (Arch: `pandoc-bin`, no `pandoc-cli` — este último entra en conflicto y trae ~675MB de dependencias GHC)
- O descarga `deepwiki` / `deepwiki-chimera` (musl, para Chimera Linux) de
  [Releases](https://github.com/SrDicov/deepwiki-scraper-cli/releases)

## Compilar

```
v -prod -o deepwiki .   # glibc
v test .                # 19 tests
```

Estático musl (Chimera): `v -cc musl-gcc -cflags "-static" -gc none -d musl -prod -o deepwiki-chimera .`

## Uso

```
./deepwiki <usuario/repo | URL GitHub | URL DeepWiki>
./deepwiki sindresorhus/is                     # crea is.txt + is.pdf
./deepwiki sindresorhus/is --output manual.pdf # stdout + PDF ahí
./deepwiki - < wiki.md | wc -c                 # filtro stdin, sin ficheros
```

Sin `--output`: guarda `<repo>.txt` (siempre primero) y `<repo>.pdf`,
stdout en silencio. `-` lee markdown de stdin (tuberías y redirecciones).

Variables: `DEEPWIKI_RETRY_DELAY` (ms, 250), `DEEPWIKI_MAX_RETRIES` (3),
`TMPDIR`. Reintenta ante 429, 502–504, errores de red y errores JSON-RPC.

## Licencia

GPL-3.0 — ver [LICENSE](LICENSE). Por Dicov.
