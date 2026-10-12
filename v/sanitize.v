module main

// Saneado del markdown para que pandoc+typst no aborten. Réplica la
// semántica de pdf-generator.ts con un parser manual (sin regex: portable y
// determinista entre versiones de V; V/regex no soporta los lookahead del
// original). Todo el escaneo es a nivel de bytes: los delimitadores
// ([ ] ( ) < >) son ASCII, así que el UTF-8 nunca se rompe.

// 1) Enlaces vacíos [t]() / [t](   ) o internos [t](#...) -> t.
//    Réplica exacta de la regex global de pdf-generator.ts:
//    /\[((?:\[[^\]]*\]|[^\[\]]|\\.)*)\]\((?:#[^\)]*|\s*)\)/g hasta punto fijo.
//    Anclaje en el '[' más a la izquierda, texto más largo primero
//    (greedy + backtrack) y avance tras el match (lastIndex). Sin trato
//    especial a escapes: la regex tampoco lo tiene ('\[' abre match).
//    Todo a nivel de bytes (delimitadores ASCII; el UTF-8 no se rompe).
fn strip_empty_links(s string) string {
	mut out := s
	mut next := strip_links_once(out)
	for next != out {
		out = next
		next = strip_links_once(out)
	}
	return out
}

// 91='[', 93=']', 92='\', 40='(', 41=')', 35='#'.
fn is_space_byte(c u8) bool {
	return c == 9 || c == 10 || c == 11 || c == 12 || c == 13 || c == 32
}

// ¿Casa s[from..to] completo con (?:\[[^\]]*\]|[^\[\]]|\\.)* ?
// Determinista: en '[' solo vale el par (contenido sin ']', cierra el
// primer ']'); ']' suelto falla. OJO: '\' cuenta como char normal — la
// alternativa \\. es inalcanzable porque el motor prueba [^\[\]] antes
// y '\' no es corchete (verificado contra el motor real).
fn text_ok(b []u8, from int, to int) bool {
	mut k := from
	for k < to {
		c := b[k]
		if c == 91 {
			mut j := k + 1
			for j < to && b[j] != 93 {
				j++
			}
			if j >= to {
				return false
			}
			k = j + 1
			continue
		}
		if c == 93 {
			return false
		}
		k++
	}
	return true
}

// Desde el ']' en m (s[m+1] debe ser '('): índice tras el ')' si el target
// es interior (#...) o vacío/blanco — réplica (?:#[^\)]*|\s*)\) —, -1 si no.
fn target_end(s string, m int) int {
	if m + 1 >= s.len || s[m + 1] != 40 {
		return -1
	}
	mut k := m + 2
	if k < s.len && s[k] == 35 {
		for k < s.len && s[k] != 41 {
			k++
		}
		if k >= s.len {
			return -1
		}
		return k + 1
	}
	for k < s.len && is_space_byte(s[k]) {
		k++
	}
	if k < s.len && s[k] == 41 {
		return k + 1
	}
	return -1
}

struct LinkSpan {
	open  int // índice del '['
	close int // índice justo después del ')'
	text  string
}

// Intenta el match que abre en `open`: cierres de derecha a izquierda
// (texto más largo primero = greedy). Orden idéntico al motor JS.
fn match_link_at(s string, b []u8, open int, closes []int) ?LinkSpan {
	for idx := closes.len - 1; idx >= 0; idx-- {
		m := closes[idx]
		if m <= open {
			break
		}
		end := target_end(s, m)
		if end < 0 {
			continue
		}
		if text_ok(b, open + 1, m) {
			return LinkSpan{
				open:  open
				close: end
				text:  s[open + 1..m]
			}
		}
	}
	return none
}

fn strip_links_once(s string) string {
	b := s.bytes()
	// Cierres candidatos: todo ']' seguido de '('.
	mut closes := []int{}
	for i := 0; i + 1 < s.len; i++ {
		if b[i] == 93 && b[i + 1] == 40 {
			closes << i
		}
	}
	mut spans := []LinkSpan{}
	mut i := 0
	for i < s.len {
		if b[i] == 91 {
			if span := match_link_at(s, b, i, closes) {
				spans << span
				i = span.close
				continue
			}
		}
		i++
	}
	if spans.len == 0 {
		return s
	}
	mut out := []u8{cap: s.len}
	mut pos := 0
	for sp in spans {
		if sp.open < pos {
			continue // defensa: nunca solapar; mejor conservar que abortar
		}
		out << b[pos..sp.open]
		out << sp.text.bytes()
		pos = sp.close
	}
	out << b[pos..]
	return out.bytestr()
}

// 2) <details>[```html]<summary>T</summary>C</details> -> **T**\n\nC\n.
//    Esos bloques HTML se verían como texto literal en el PDF.
fn unwrap_details(s string) string {
	mut out := s
	for {
		d := out.index('<details>') or { break }
		sum_o := out.index_after('<summary>', d) or { break }
		sum_c := out.index_after('</summary>', sum_o + 9) or { break }
		end := out.index_after('</details>', sum_c + 10) or { break }
		title := out[sum_o + 9..sum_c].trim_space()
		content := out[sum_c + 10..end].trim_space()
		out = out[..d] + '**' + title + '**\n\n' + content + '\n' + out[end + 10..]
	}
	return out
}
