import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';

export async function generatePdf(mdPath: string, outputFilename: string): Promise<void> {
  console.log('Iniciando fase de ensamblaje y tipografía (PDF)...');

  if (!fs.existsSync(mdPath)) {
    throw new Error(`No se encontró ${mdPath}. Ejecuta la extracción primero.`);
  }

  const markdown = fs.readFileSync(mdPath, 'utf-8');

  // Parche para Typst: falla la compilación entera si hay referencias internas (#) no encontradas
  // o enlaces vacíos (producen #link("") y Typst aborta).
  // Reemplazamos todos los enlaces vacíos () o internos (#algo) por simplemente su texto.
  // El texto puede contener corchetes anidados ([[...]]()) o escapados (\[...\]) — en bucle
  // hasta punto fijo porque un enlace externo puede envolver otro interno ([[`a`]() , `b`]())
  // y una sola pasada dejaría el interno intacto.
  let cleanedContent = markdown;
  let prev: string;
  do {
    prev = cleanedContent;
    cleanedContent = cleanedContent.replace(/\[((?:\[[^\]]*\]|[^\[\]]|\\.)*)\]\((?:#[^\)]*|\s*)\)/g, '$1');
  } while (cleanedContent !== prev);

  // Parche para Pandoc/Typst: DeepWiki envuelve listas de archivos fuente en <details><summary>...
  // </summary>...</details>. Esos bloques HTML se renderizan como texto literal en el PDF.
  // Los convertimos a markdown plano: **Título**\n\nContenido
  // Parche para Pandoc: DeepWiki emite bloques ---\n**Sources:**\n...\n--- entre páginas;
  // Pandoc los lee como bloque YAML frontmatter y aborta ("did not find expected ... alias"
  // por las líneas "* ..."). Se desactiva la extensión yaml_metadata_block: el wiki nunca
  // trae frontmatter real (empieza por "# Page:"), y --- sigue renderizando como regla horizontal.
  // (Esto también cubre el antiguo caso ---\n```# Page:, ya sin parche dedicado.)
  cleanedContent = cleanedContent.replace(
    /<details>\s*(?:```html\s*)?<summary>(.*?)<\/summary>\s*([\s\S]*?)\s*<\/details>/g,
    (_, title, content) => `**${title.trim()}**\n\n${content.trim()}\n`
  );

  const consolidatedPath = path.resolve(process.cwd(), 'consolidated.md');
  const outputPath = path.resolve(process.cwd(), outputFilename);
  fs.writeFileSync(consolidatedPath, cleanedContent, 'utf-8');
  console.log('Archivo maestro consolidado temporal creado.');
  console.log('Invocando a Pandoc con motor Typst...');

  return new Promise((resolve, reject) => {
    // Comando: pandoc consolidated.md -o outputFilename --pdf-engine=typst
    // -f markdown-citations-yaml_metadata_block: sin citeproc las citas [@repo] se quedan
    // como texto plano; si no, Pandoc las emite como #cite(...) y Typst aborta sin bibliografía.
    // -yaml_metadata_block: los --- entre páginas no son frontmatter (ver arriba).
    const pandoc = spawn('pandoc', [
      consolidatedPath,
      '-o',
      outputPath,
      '-f',
      'markdown-citations-yaml_metadata_block',
      '--pdf-engine=typst'
    ]);

    pandoc.stdout.on('data', (data) => {
      console.log(`Pandoc: ${data}`);
    });

    pandoc.stderr.on('data', (data) => {
      console.error(`Pandoc Warning/Error: ${data}`);
    });

    // Sin este handler, spawn fallido (pandoc no está en PATH) crashea el proceso
    pandoc.on('error', (err) => {
      reject(err);
    });

    pandoc.on('close', (code) => {
      if (code === 0) {
        console.log(`¡PDF generado exitosamente en: ${outputPath}!`);
        // Limpiamos el archivo temporal
        if (fs.existsSync(consolidatedPath)) {
          fs.unlinkSync(consolidatedPath);
        }
        resolve();
      } else {
        reject(new Error(`Pandoc falló y terminó con código de error ${code}`));
      }
    });
  });
}