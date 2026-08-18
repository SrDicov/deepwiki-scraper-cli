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
  // Reemplazamos todos los enlaces vacíos () o internos (#algo) por simplemente su texto.
  // El texto puede contener corchetes anidados ([[...]]()) o escapados (\[...\]) — ponytail:
  // soporta 1 nivel de anidamiento, más niveles romperían Typst otra vez
  const cleanedContent = markdown.replace(/\[((?:\[[^\]]*\]|[^\[\]]|\\.)*)\]\((?:#[^\)]*|\s*)\)/g, '$1');

  const consolidatedPath = path.resolve(process.cwd(), 'consolidated.md');
  const outputPath = path.resolve(process.cwd(), outputFilename);
  fs.writeFileSync(consolidatedPath, cleanedContent, 'utf-8');
  console.log('Archivo maestro consolidado temporal creado.');
  console.log('Invocando a Pandoc con motor Typst...');

  return new Promise((resolve, reject) => {
    // Comando: pandoc consolidated.md -o outputFilename --pdf-engine=typst
    // -f markdown-citations: sin citeproc las citas [@repo] se quedan como texto plano;
    // si no, Pandoc las emite como #cite(...) y Typst aborta sin bibliografía
    const pandoc = spawn('pandoc', [
      consolidatedPath,
      '-o',
      outputPath,
      '-f',
      'markdown-citations',
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