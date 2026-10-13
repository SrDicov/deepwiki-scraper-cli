module main

import os

// Entrecomillado POSIX siempre seguro: ' -> '\''
fn sh_quote(s string) string {
	return "'" + s.replace("'", "'\\''") + "'"
}

// Absolutiza contra el CWD (pandoc se invoca con rutas absolutas para no
// depender de su CWD interno).
fn cwd_join(name string) string {
	if name.starts_with('/') {
		return name
	}
	return os.join_path(os.getwd(), name)
}

// Temporal en TMPDIR (respeta la convención; cae a /tmp). Único por PID.
fn tmp_markdown() string {
	mut base := os.getenv('TMPDIR')
	if base == '' {
		base = '/tmp'
	}
	return base + '/deepwiki-' + os.getpid().str() + '.md'
}

// Renderiza markdown (en memoria) a PDF vía pandoc+typst. Réplica los
// parches de pdf-generator.ts:
//   -f markdown-citations-yaml_metadata_block: las citas [@x] quedan como
//    texto plano (sin esto pandoc emite #cite(...) y typst aborta sin
//    bibliografía); los '---' entre páginas no son frontmatter YAML.
//   -V mainfont='Libertinus Serif': la plantilla de pandoc<3.10 emite
//    font:() y typst>=0.13 aborta ("font fallback list must not be empty");
//    la fuente viene embebida en typst, sin paquetes de fuentes del sistema.
fn render_pdf(markdown string, output_pdf string) ! {
	for bin in ['pandoc', 'typst'] {
		if os.execute('command -v ' + bin).exit_code != 0 {
			return error("E_IO '${bin}' no está en PATH (PDF requiere pandoc + typst)")
		}
	}
	clean := unwrap_details(strip_empty_links(markdown))
	tmp := tmp_markdown()
	os.write_file(tmp, clean) or {
		return error('E_IO no se pudo escribir el temporal ${tmp}: ${err.msg()}')
	}
	eprintln('maestro temporal: ${tmp}')
	eprintln('invocando pandoc + typst...')
	cmd := 'pandoc ' + sh_quote(tmp) + ' -o ' + sh_quote(cwd_join(output_pdf)) +
		" -f 'markdown-citations-yaml_metadata_block'" + ' --pdf-engine=typst' +
		" -V 'mainfont=Libertinus Serif'"
	res := os.execute(cmd)
	if res.exit_code == 0 {
		os.rm(tmp) or {}
		eprintln('PDF generado: ${cwd_join(output_pdf)}')
		return
	}
	if res.output.trim_space() != '' {
		eprintln(res.output)
	}
	return error('E_IO pandoc falló (código ${res.exit_code}); temporal conservado en ${tmp}')
}
