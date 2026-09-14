import fs from 'fs';
import path from 'path';
import { callTool } from './mcp-client.js';
import { withExponentialBackoff } from './resilience.js';
import { generatePdf } from './pdf-generator.js';
import { translateToLanguage } from './translator.js';

async function main() {
  const args = process.argv.slice(2);
  const repoName = args.find(arg => !arg.startsWith('-'));
  const outputIndex = args.indexOf('--output');
  const outputFilename = outputIndex !== -1 ? args[outputIndex + 1] : undefined;
  const langIndex = args.indexOf('--lang');
  const targetLang = langIndex !== -1 ? args[langIndex + 1] : undefined;

  if (!repoName) {
    console.error('Uso: npx tsx src/index.ts <usuario/repositorio> [--output <archivo.pdf>] [--lang <idioma>]');
    process.exit(1);
  }

  console.log(`Extrayendo documentación para: ${repoName}`);
  const contentsRes = await withExponentialBackoff(() => callTool(repoName, 'read_wiki_contents'));
  let markdown: string = contentsRes?.content?.[0]?.text || '';

  if (!markdown) {
    console.warn('No se recibió contenido markdown.');
    process.exit(1);
  }

  if (targetLang) {
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      console.error('Error: se requiere OPENROUTER_API_KEY para traducir. Defínela en el entorno.');
      process.exit(1);
    }

    console.log(`Traduciendo a: ${targetLang}`);
    const pages = markdown.split(/(?=# Page: )/).filter(Boolean);
    const translatedPages = await Promise.all(
      pages.map(page => translateToLanguage(page, targetLang, apiKey))
    );
    markdown = translatedPages.join('');
    console.log(`Traducción completada (${markdown.length} caracteres).`);
  }

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
