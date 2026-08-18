import crypto from 'crypto';

export async function callTool(repoName: string, toolName: string): Promise<any> {
  const response = await fetch('https://mcp.deepwiki.com/mcp', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      // Header obligatorio para el transporte Streamable HTTP en MCP
      'Accept': 'application/json, text/event-stream'
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: crypto.randomUUID(),
      method: 'tools/call',
      params: { name: toolName, arguments: { repoName } }
    })
  });

  if (!response.ok) {
    const error: any = new Error(`HTTP Error: ${response.status}`);
    error.status = response.status;
    throw error;
  }

  const text = await response.text();
  let jsonString = text;

  // Las respuestas SSE llegan como "event: message\ndata: {...}"
  if (response.headers.get('content-type')?.includes('text/event-stream')) {
    const dataLine = text.split('\n').find(line => line.startsWith('data: '));
    if (dataLine) {
      jsonString = dataLine.slice('data: '.length);
    }
  }

  const data = JSON.parse(jsonString);
  if (data.error) {
    throw new Error(`JSON-RPC Error [${data.error.code}]: ${data.error.message}`);
  }

  return data.result;
}