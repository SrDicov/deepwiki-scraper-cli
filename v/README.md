# deepwiki (port V) — filosofía UNIX/POSIX

Binario único y estático (sin Node/npm): descarga la wiki completa de un
repo desde DeepWiki vía MCP y opcionalmente genera el PDF offline.

## Compilar

```
cd v && v -prod -o deepwiki .
```

Solo stdlib de V (`os`, `net.http`, `json`, `time`). El PDF sigue
requiriendo `pandoc` + `typst` en el PATH (se invocan como subprocesos).

## Testear

```
cd v && v test .   # 19 tests: todas las funciones puras + backoff con doble
```

Cobertura viva además: `difftest.py` compara el saneador contra el motor
JS en 32 casos adversariales + wikis reales (34/34 idénticos).

## Chimera Linux (musl, estático)

Chimera no es glibc: el binario normal no corre allí. Receta verificada
(toolchain musl.cc en `~/x86_64-linux-musl-cross`, **sin** `CPATH` de glibc):

```
MGC=$HOME/x86_64-linux-musl-cross/bin/x86_64-linux-musl-gcc
v -cc $MGC -cflags "-static" -gc none -d musl -prod -o deepwiki-chimera .
```

Claves: `-d musl` (V no autodetecta musl con `-cc` custom; sin esto falla
`backtrace_symbols`), `-gc none` (Boehm no enlaza estático contra musl),
`-static`. TLS va por mbedtls empaquetado: cero dependencias (`ldd` dice
`statically linked`, 1.9 MB). Salida verificada byte-idéntica a la glibc.
En Chimera solo faltan `pandoc`, `typst` y CA certs (`apk add pandoc typst
ca-certificates`) para el PDF y el HTTPS.

## Usar

```
./deepwiki <usuario/repo | URL GitHub | URL DeepWiki>
./deepwiki sindresorhus/is                        # crea is.txt + is.pdf
./deepwiki sindresorhus/is --output manual.pdf    # stdout + PDF ahí
./deepwiki sindresorhus/is --output manual.pdf > copia.md
./deepwiki - < wiki.md | wc -c                    # filtro por tubería
```

Sin `--output`: guarda `<repo>.txt` (siempre primero) y `<repo>.pdf`,
stdout en silencio. Con `--output`: markdown a stdout + PDF a esa ruta.
Con `-`: lee de stdin (sin fetch, sin ficheros por defecto).

## Reglas UNIX aplicadas

- Datos a **stdout** (modo filtro) o a **ficheros explícitos** (`<repo>.txt`
  primero, luego `<repo>.pdf`); diagnósticos a **stderr**; salida `1` ante
  cualquier error (mismo código que el original).
- Sin ficheros mágicos: no hay `deepwiki.md`/`consolidated.md` ni wrapper
  `start.sh` (lógica de URLs dentro del binario).
  El temporal del PDF vive en `$TMPDIR` (o `/tmp`), único por PID; se borra
  al éxito y se conserva al fallo (la ruta se avisa por stderr).
- El `.txt` se escribe ANTES de invocar pandoc: si el PDF falla, los datos
  ya están a salvo (en modo filtro, van antes a stdout).
- Argumentos mínimos estilo original + `-h/--help`, `-V/--version`.

## Diferencias deliberadas con el TS

1. `isError:true` del MCP (repo inexistente, verificado contra el endpoint)
   ahora es error fatal `E_TOOL`, no markdown válido → adiós PDFs basura.
2. `--output` sin valor = error de uso (el TS lo tragaba en silencio).
3. Opción desconocida / repo duplicado = error de uso (el TS lo ignoraba).
4. Sin `deepwiki.md` persistente ni wrapper: el binario acepta URLs y
   escribe `<repo>.txt`/`<repo>.pdf` por defecto.
5. Jitter sin `rand` (PID + intento): un import menos, igual decorrelación.

## Variables (mismos nombres que el original)

`DEEPWIKI_RETRY_DELAY` (ms, 250), `DEEPWIKI_MAX_RETRIES` (3), `TMPDIR`.
Reintento en 429, 502–504, red y `data.error` JSON-RPC (igual que el
original); JSON malformado, `E_TOOL` y E/S no reintentan.

## Mapeo TS → V

| TS | V | Nota |
|---|---|---|
| `src/index.ts` | `main.v` | orquestación + argv manual |
| `src/mcp-client.ts` | `mcp_client.v` | `net.http` + `json`; SSE por olfato, no por cabecera |
| `src/resilience.ts` | `resilience.v` | `E_*` + `time.sleep`; jitter sin `rand` |
| `src/pdf-generator.ts` | `pdf_generator.v` + `sanitize.v` | parser manual (V/regex no tiene lookahead); pandoc vía `os.execute` con entrecomillado POSIX |
| `src/translator.ts` | — (eliminado) | sin traducción: menos código, sin API keys, sin costo por página |
| `start.sh` (sh) | `normalize_slug()` en `main.v` | misma normalización, verificada 1:1 (32 casos); sin wrapper |
