module main

import net.http
import json
import os

const mcp_url = 'https://mcp.deepwiki.com/mcp'

struct RpcRequest {
	jsonrpc string
	id      string
	method  string
	params  RpcParams
}

struct RpcParams {
	name      string
	arguments map[string]string
}

struct McpContent {
	typ  string @[json: 'type']
	text string
}

struct McpResult {
	content  []McpContent
	is_error bool @[json: 'isError']
}

struct RpcOk {
	result McpResult
}

struct RpcErrInner {
	code    int
	message string
}

struct RpcErr {
	error RpcErrInner @[json: 'error']
}

// Las respuestas SSE llegan como "event: message\ndata: {...}".
// Si el cuerpo no es SSE se devuelve tal cual (tolerante al content-type:
// no dependemos de la cabecera de respuesta).
fn sse_unwrap(body string) string {
	if body.starts_with('event:') || body.contains('\ndata: ') {
		for line in body.split_into_lines() {
			if line.starts_with('data: ') {
				return line[6..]
			}
		}
	}
	return body
}

fn clip(s string, n int) string {
	t := s.trim_space()
	if t.len > n {
		return t[..n] + '…'
	}
	return t
}

// Llama a read_wiki_contents. Devuelve el markdown o un error 'E_*'.
// DIFIERE del original a propósito: los errores de herramienta
// (isError:true, p.ej. repo inexistente) antes se trataban como markdown
// válido y generaban un PDF basura; ahora son fatales (E_TOOL, sin reintento).
fn fetch_wiki(repo string) !string {
	mut args_map := map[string]string{}
	args_map['repoName'] = repo
	payload := json.encode(RpcRequest{
		jsonrpc: '2.0'
		id:      'deepwiki-${os.getpid()}'
		method:  'tools/call'
		params:  RpcParams{
			name:      'read_wiki_contents'
			arguments: args_map
		}
	})
	mut hdr := http.new_header()
	hdr.add(.content_type, 'application/json')
	// Cabecera obligatoria del transporte MCP Streamable HTTP.
	hdr.add(.accept, 'application/json, text/event-stream')
	resp := http.fetch(http.FetchConfig{
		method: http.Method.post
		url:    mcp_url
		header: hdr
		data:   payload
	}) or { return error('E_NET fallo de red hacia ${mcp_url}: ${err.msg()}') }
	if resp.status_code < 200 || resp.status_code >= 300 {
		return error('E_HTTP ${resp.status_code}')
	}
	body := sse_unwrap(resp.body)
	// Sonda de error primero: el sobre de éxito no trae clave "error".
	probe := json.decode(RpcErr, body) or {
		return error('E_JSON respuesta no-JSON del servidor MCP')
	}
	if probe.error.message != '' {
		return error('E_RPC JSON-RPC Error [${probe.error.code}]: ${probe.error.message}')
	}
	ok := json.decode(RpcOk, body) or { return error('E_JSON respuesta JSON-RPC ilegible') }
	if ok.result.content.len == 0 {
		return ''
	}
	if ok.result.is_error {
		return error('E_TOOL ${clip(ok.result.content[0].text, 200)}')
	}
	return ok.result.content[0].text
}
