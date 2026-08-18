# DeepWiki Scraper CLI

CLI en TypeScript que descarga la documentación completa de cualquier repositorio en [DeepWiki](https://deepwiki.com) a través de su API MCP y la compila en un único PDF navegable y offline.

## Características

- Descarga el wiki completo (todas las páginas) en una sola llamada JSON-RPC sobre MCP (`https://mcp.deepwiki.com/mcp`)
- Almacena el markdown en `deepwiki.md` (almacén persistente, se sobrescribe en cada ejecución)
- Genera el PDF con Pandoc + Typst
- Exponential backoff con jitter ante rate limits y errores de red

## Requisitos

- Node.js >= 18 (`fetch` global)
- Binarios de [Pandoc](https://pandoc.org) y [Typst](https://typst.app) en el PATH

## Instalación

```
npm install
```

## Uso

```
npx tsx src/index.ts <usuario/repositorio> [--output <archivo.pdf>]
```

Ejemplos:

```
npx tsx src/index.ts sindresorhus/is --output manual.pdf   # descarga + PDF
npx tsx src/index.ts sindresorhus/is                       # solo descarga
```

Salidas (relativas al CWD): `deepwiki.md` (almacén de markdown), `consolidated.md` (temporal, se borra al éxito), el PDF.

Variables de entorno: `DEEPWIKI_RETRY_DELAY` (ms, por defecto 250), `DEEPWIKI_MAX_RETRIES` (por defecto 3). Reintenta ante HTTP 429, 502–504 y errores de red.

## Arquitectura

- `src/index.ts` — punto de entrada del CLI: descarga + PDF opcional
- `src/mcp-client.ts` — cliente JSON-RPC del endpoint MCP de DeepWiki (parsing SSE)
- `src/resilience.ts` — wrapper de backoff exponencial
- `src/pdf-generator.ts` — markdown a PDF con Pandoc/Typst; elimina enlaces y citas que romperían Typst

## Licencia

GPL-3.0 — ver [LICENSE](LICENSE).

## Créditos

Desarrollado por Dicov.
