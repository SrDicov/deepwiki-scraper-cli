module main

import os

const version = '0.0.1'

fn usage() {
	eprintln('uso: deepwiki <usuario/repo|URL|-> [--output <archivo.pdf>]')
	eprintln('     deepwiki -h | --help | -V | --version')
	eprintln('')
	eprintln('  Descarga la wiki de DeepWiki vía MCP. Acepta usuario/repo o')
	eprintln('  links de GitHub/DeepWiki (normaliza a usuario/repo).')
	eprintln('  Sin --output: guarda <repo>.txt (siempre primero) y <repo>.pdf;')
	eprintln('  con --output: el markdown va a stdout y el PDF a esa ruta.')
	eprintln("  Con '-' lee el markdown de stdin (filtro por tubería).")
	eprintln('  Diagnósticos a stderr. PDF requiere pandoc + typst.')
	eprintln('  Variables: DEEPWIKI_RETRY_DELAY (ms, 250), DEEPWIKI_MAX_RETRIES (3),')
	eprintln('             TMPDIR (temporal PDF).')
}

fn main() {
	run() or {
		eprintln('error: ${err.msg()}')
		exit(1)
	}
}

// Lee stdin completo sin asumir seekable (vale para pipes y redirects).
fn read_stdin_all() !string {
	f := os.stdin()
	mut out := []u8{}
	mut buf := []u8{len: 65536}
	for {
		n := f.read(mut buf) or {
			if err is os.Eof {
				break
			}
			return err
		}
		out << buf[..n]
	}
	return out.bytestr()
}

// Normaliza 'usuario/repo', URL de GitHub o URL de DeepWiki a 'usuario/repo'.
// Réplica exacta del antiguo start.sh: quita query/fragmento, '/' final y
// '.git'; corta el dominio; toma los 2 primeros segmentos e ignora el resto
// (p.ej. /issues/5); rechaza vacíos. Verificado 1:1 contra el sh (32 casos).
fn normalize_slug(raw string) !string {
	mut s := raw
	q := s.index('?') or { -1 }
	if q >= 0 {
		s = s[..q]
	}
	h := s.index('#') or { -1 }
	if h >= 0 {
		s = s[..h]
	}
	if s.ends_with('/') && s.len > 1 {
		s = s[..s.len - 1]
	}
	if s.ends_with('.git') && s.len > 4 {
		s = s[..s.len - 4]
	}
	for dom in ['github.com/', 'deepwiki.com/'] {
		di := s.index(dom) or { -1 }
		if di >= 0 {
			s = s[di + dom.len..]
			break
		}
	}
	parts := s.split('/')
	if parts.len < 2 || parts[0] == '' || parts[1] == '' {
		return error("no pude extraer usuario/repo de '${raw}'")
	}
	return parts[0] + '/' + parts[1]
}

fn run() ! {
	args := os.args
	mut repo := ''
	mut output_pdf := ''
	mut explicit_output := false
	mut i := 1
	for i < args.len {
		a := args[i]
		if a == '--output' {
			if i + 1 >= args.len {
				usage()
				return error('falta el valor de --output')
			}
			output_pdf = args[i + 1]
			explicit_output = true
			i += 2
		} else if a == '-h' || a == '--help' {
			usage()
			return
		} else if a == '-V' || a == '--version' {
			println('deepwiki ${version}')
			return
		} else if a.len > 1 && a.starts_with('-') {
			usage()
			return error("opción desconocida: '${a}'")
		} else if repo == '' {
			repo = a
			i++
		} else {
			usage()
			return error("argumento inesperado: '${a}'")
		}
	}
	if repo == '' {
		usage()
		return error('falta <usuario/repo>')
	}
	// '-' = filtro: el markdown entra por stdin, sin red (composición UNIX).
	// Se lee por chunks hasta EOF: funciona con tuberías, no solo con
	// redirección de ficheros (os.read_file hace fseek y falla en pipes).
	mut md := ''
	mut repo_name := ''
	if repo == '-' {
		md = read_stdin_all() or {
			return error('no se pudo leer stdin: ${err.msg()}')
		}
	} else {
		slug := normalize_slug(repo) or {
			usage()
			return error(err.msg())
		}
		repo_name = slug.split('/')[1]
		eprintln('extrayendo documentación para: ${slug}')
		md = with_backoff(fn [slug] () !string {
			return fetch_wiki(slug)
		}, max_retries(), retry_delay_ms())!
	}
	if md == '' {
		return error('no se recibió contenido markdown')
	}
	// Salida: con --output explícito se conserva el modo filtro (markdown a
	// stdout + PDF a la ruta). Sin --output se crean <repo>.txt (SIEMPRE
	// primero: prioridad al .txt, sobrevive si el PDF falla) y <repo>.pdf;
	// stdout queda en silencio y el exit es no-cero si el PDF falla.
	if repo == '-' || explicit_output {
		print(md)
	} else {
		txt_path := repo_name + '.txt'
		os.write_file(txt_path, md) or {
			return error('E_IO no se pudo escribir ${txt_path}: ${err.msg()}')
		}
		eprintln('guardado: ${txt_path} (${md.len} B)')
		output_pdf = repo_name + '.pdf'
	}
	if output_pdf != '' {
		render_pdf(md, output_pdf)!
	}
}
