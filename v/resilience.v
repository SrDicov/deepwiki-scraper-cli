module main

import os
import time

// Límites configurables por entorno (mismos nombres que el original TS).
fn retry_delay_ms() int {
	return env_int('DEEPWIKI_RETRY_DELAY', 250)
}

fn max_retries() int {
	return env_int('DEEPWIKI_MAX_RETRIES', 3)
}

fn env_int(name string, def int) int {
	v := os.getenv(name).trim_space()
	if v == '' {
		return def
	}
	for c in v.bytes() {
		if c < 48 || c > 57 { // no es dígito ASCII: se ignora el valor
			return def
		}
	}
	return v.int()
}

// Clasificación de errores. Formato interno: 'E_TIPO resto'.
// Reintentables: red (E_NET), HTTP 429/502-504 y JSON-RPC sin status (E_RPC;
// igual que el original: el cliente lanza un error plano sin status).
// Fatales: JSON malformado (E_JSON), error de herramienta (E_TOOL) y
// E/S (E_IO).
fn is_retryable(msg string) bool {
	if msg.starts_with('E_NET ') {
		return true
	}
	if msg.starts_with('E_RPC ') {
		return true
	}
	if msg.starts_with('E_HTTP ') {
		code := msg[7..].split(' ')[0].int()
		return code == 429 || (code >= 502 && code <= 504)
	}
	return false
}

fn short_msg(msg string) string {
	if msg.len > 120 {
		return msg[..120] + '…'
	}
	return msg
}

// Jitter decorrelacionado por PID y por intento: evita ráfagas sincronizadas
// sin importar 'rand' (binario mínimo, portable).
fn jitter_ms(attempt int) int {
	return (os.getpid() * 31 + attempt * 37 + 11) % 100
}

fn sleep_ms(ms int) {
	time.sleep(time.Duration(i64(ms) * 1_000_000))
}

// Backoff exponencial: DELAY * 2^intento + jitter. Réplica resilience.ts.
fn with_backoff(op fn () !string, retries int, base_delay int) !string {
	mut last_err := ''
	for attempt := 0; attempt <= retries; attempt++ {
		res := op() or {
			last_err = err.msg()
			if is_retryable(last_err) && attempt < retries {
				delay := base_delay * (1 << attempt) + jitter_ms(attempt)
				eprintln('[límite/timeout] intento ${attempt + 1} fallido (${short_msg(last_err)}). reintentando en ${delay}ms...')
				sleep_ms(delay)
				continue
			}
			return error(last_err)
		}
		return res
	}
	return error(last_err)
}
