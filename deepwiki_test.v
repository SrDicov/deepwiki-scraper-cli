module main

import os

// Cobertura de todas las funciones puras del port. Se corre con: v test

fn test_env_int() {
	os.unsetenv('DEEPWIKI_TEST_X')
	assert env_int('DEEPWIKI_TEST_X', 7) == 7
	os.setenv('DEEPWIKI_TEST_X', '42', true)
	assert env_int('DEEPWIKI_TEST_X', 7) == 42
	os.setenv('DEEPWIKI_TEST_X', '  9  ', true)
	assert env_int('DEEPWIKI_TEST_X', 7) == 9
	os.setenv('DEEPWIKI_TEST_X', 'abc', true)
	assert env_int('DEEPWIKI_TEST_X', 7) == 7
	os.setenv('DEEPWIKI_TEST_X', '-1', true)
	assert env_int('DEEPWIKI_TEST_X', 7) == 7
	os.setenv('DEEPWIKI_TEST_X', '', true)
	assert env_int('DEEPWIKI_TEST_X', 7) == 7
	os.unsetenv('DEEPWIKI_TEST_X')
}

fn test_is_retryable() {
	assert is_retryable('E_NET caído') == true
	assert is_retryable('E_RPC JSON-RPC Error [1]: x') == true
	assert is_retryable('E_HTTP 429') == true
	assert is_retryable('E_HTTP 502') == true
	assert is_retryable('E_HTTP 503 boom') == true
	assert is_retryable('E_HTTP 504') == true
	assert is_retryable('E_HTTP 404') == false
	assert is_retryable('E_HTTP 500') == false
	assert is_retryable('E_HTTP 200') == false
	assert is_retryable('E_JSON roto') == false
	assert is_retryable('E_TOOL no existe') == false
	assert is_retryable('E_XXX desconocido') == false
	assert is_retryable('E_IO disco') == false
	assert is_retryable('otra cosa') == false
	assert is_retryable('') == false
}

fn test_short_msg() {
	assert short_msg('corto') == 'corto'
	long := 'x'.repeat(200)
	assert short_msg(long).len == 123
	assert short_msg(long).ends_with('…')
}

fn test_jitter_range() {
	for a in 0 .. 10 {
		j := jitter_ms(a)
		assert j >= 0 && j < 100
	}
}

fn test_sleep_no_crash() {
	sleep_ms(1)
}

fn test_with_backoff_reintenta() {
	mut calls := [0]
	res := with_backoff(fn [mut calls] () !string {
		calls[0]++
		if calls[0] < 3 {
			return error('E_NET caído')
		}
		return 'ok'
	}, 5, 1)!
	assert res == 'ok'
	assert calls[0] == 3
}

fn test_with_backoff_fatal_no_reintenta() {
	mut calls := [0]
	with_backoff(fn [mut calls] () !string {
		calls[0]++
		return error('E_TOOL no')
	}, 5, 1) or {
		assert calls[0] == 1
		assert err.msg() == 'E_TOOL no'
		return
	}
	assert false, 'with_backoff debió propagar el error fatal'
}

fn test_with_backoff_agota_reintentos() {
	mut calls := [0]
	with_backoff(fn [mut calls] () !string {
		calls[0]++
		return error('E_NET caído')
	}, 2, 1) or {
		assert calls[0] == 3
		assert err.msg() == 'E_NET caído'
		return
	}
	assert false, 'with_backoff debió agotar los reintentos'
}

fn test_sse_unwrap() {
	assert sse_unwrap('{"a":1}') == '{"a":1}'
	assert sse_unwrap("event: message\ndata: {\"a\":1}\n\n") == '{"a":1}'
	assert sse_unwrap("event: message\ndata: {\"a\":1}\ndata: {\"b\":2}") == '{"a":1}'
	assert sse_unwrap('') == ''
	assert sse_unwrap("not sse\ndata: x") == 'x'
}

fn test_clip() {
	assert clip('  abc  ', 10) == 'abc'
	big := 'y'.repeat(300)
	c := clip(big, 200)
	assert c.len == 203
	assert c.ends_with('…')
}

fn test_text_ok() {
	assert text_ok('abc'.bytes(), 0, 3) == true
	assert text_ok('a[b]c'.bytes(), 0, 5) == true
	assert text_ok('a]b'.bytes(), 0, 3) == false
	assert text_ok('[ab'.bytes(), 0, 3) == false
	assert text_ok('[[a]b]'.bytes(), 0, 6) == false
	assert text_ok('a\\'.bytes(), 0, 2) == true
	assert text_ok('a\\]b'.bytes(), 0, 4) == false
	assert text_ok(''.bytes(), 0, 0) == true
}

fn test_target_end() {
	assert target_end('[t](#x)', 2) == 7
	assert target_end('[t]()', 2) == 5
	assert target_end('[t](  )', 2) == 7
	assert target_end('[t](http://e.com)', 2) == -1
	assert target_end('[t](#x', 2) == -1
	assert target_end('[t]#x)', 2) == -1
	assert target_end('[t]', 2) == -1
}

fn test_is_space_byte() {
	assert is_space_byte(32) == true
	assert is_space_byte(10) == true
	assert is_space_byte(9) == true
	assert is_space_byte(65) == false
	assert is_space_byte(91) == false
}

fn test_strip_links() {
	assert strip_empty_links('[t](#x)') == 't'
	assert strip_empty_links('[t]()') == 't'
	assert strip_empty_links('[t](   )') == 't'
	assert strip_empty_links('[t](http://e.com)') == '[t](http://e.com)'
	assert strip_empty_links('[t](#x) y [u](http://e.com)') == 't y [u](http://e.com)'
	assert strip_empty_links('[[a]](#x)') == '[a]'
	assert strip_empty_links("[a [b](#x)](#y)") == 'a b'
	assert strip_empty_links("sin enlaces") == "sin enlaces"
	assert strip_empty_links('[roto](#x') == '[roto](#x'
	assert strip_empty_links('[[a]() , b]()') == 'a , b'
	assert strip_empty_links("\\[t\\](#x)") == "\\t\\"
	assert strip_empty_links('[a](#x](#y)') == 'a'
	assert strip_empty_links('[t](#x [u](#y)') == 't'
}

fn test_unwrap_details() {
	assert unwrap_details('<details><summary>T</summary>C</details>') == "**T**\n\nC\n"
	assert unwrap_details("<details>\n```html\n<summary>T</summary>C</details>") == "**T**\n\nC\n"
	assert unwrap_details('<details><summary>T</summary>C') == '<details><summary>T</summary>C'
	assert unwrap_details('A<details><summary>1</summary>x</details>B<details><summary>2</summary>y</details>C') == "A**1**\n\nx\nB**2**\n\ny\nC"
	assert unwrap_details('plano') == 'plano'
}

fn test_sh_quote() {
	assert sh_quote('') == "''"
	assert sh_quote('abc-1.pdf') == "'abc-1.pdf'"
	assert sh_quote("a'b") == "'a'\\''b'"
}

fn test_cwd_join() {
	assert cwd_join('/abs/x.pdf') == '/abs/x.pdf'
	assert cwd_join('f.pdf') == os.join_path(os.getwd(), 'f.pdf')
}

fn test_tmp_markdown() {
	pid := os.getpid().str()
	p := tmp_markdown()
	assert p.ends_with('.md')
	assert p.contains(pid)
	base := os.getenv('TMPDIR')
	if base == '' {
		assert p.starts_with('/tmp/')
	} else {
		assert p.starts_with(base)
	}
	os.setenv('TMPDIR', '/tmp/opencode/audit', true)
	assert tmp_markdown().starts_with('/tmp/opencode/audit/')
	os.unsetenv('TMPDIR')
}

fn test_normalize_slug() {
	a := normalize_slug('SrDicov/musl') or { panic(err) }
	assert a == 'SrDicov/musl'
	b := normalize_slug('SrDicov/musl/') or { panic(err) }
	assert b == 'SrDicov/musl'
	c := normalize_slug('SrDicov/musl.git') or { panic(err) }
	assert c == 'SrDicov/musl'
	d := normalize_slug('https://github.com/SrDicov/musl/issues/5') or { panic(err) }
	assert d == 'SrDicov/musl'
	e := normalize_slug('https://deepwiki.com/SrDicov/zinit?x=1#f') or { panic(err) }
	assert e == 'SrDicov/zinit'
	f := normalize_slug('SrDicov/arxy?lang=es') or { panic(err) }
	assert f == 'SrDicov/arxy'
	g := normalize_slug('a/b/c') or { panic(err) }
	assert g == 'a/b'
	assert normalize_slug('foo') or { '' } == ''
	assert normalize_slug('/') or { '' } == ''
	assert normalize_slug('u//r') or { '' } == ''
	assert normalize_slug('HTTPS://GITHUB.COM/u/r') or { '' } == ''
	assert normalize_slug('github.com/u') or { '' } == ''
	h := normalize_slug('git@github.com:u/r.git') or { panic(err) }
	assert h == 'git@github.com:u/r'
}
