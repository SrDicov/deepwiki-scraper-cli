import fs from 'fs';
import path from 'path';
import { callTool } from './mcp-client.js';
import { withExponentialBackoff } from './resilience.js';
import { generatePdf } from './pdf-generator.js';

async function main() {
  const args = process.argv.slice(2);
  const repoName = args.find(arg => !arg.startsWith('-'));
  const outputIndex = args.indexOf('--output');
  const outputFilename = outputIndex !== -1 ? args[outputIndex + 1] : undefined;

  if (!repoName) {
    console.error('Uso: npx tsx src/index.ts <usuario/repositorio> [--output <archivo.pdf>]');
    process.exit(1);
  }

  console.log(`Extrayendo documentación para: ${repoName}`);
  const contentsRes = await withExponentialBackoff(() => callTool(repoName, 'read_wiki_contents'));
  const markdown = contentsRes?.content?.[0]?.text || '';

  if (!markdown) {
    console.warn('No se recibió contenido markdown.');
    process.exit(1);
  }

  // El MCP devuelve todo el wiki en un único string (páginas separadas por "# Page: ")
  const mdPath = path.resolve(process.cwd(), 'deepwiki.md');
  fs.writeFileSync(mdPath, markdown, 'utf-8');
  console.log(`Contenido guardado (${markdown.length} caracteres) en ${mdPath}`);

  if (outputFilename) {
    await generatePdf(mdPath, outputFilename);
  }
}

main().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});