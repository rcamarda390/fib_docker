import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';

const port = Number(process.env.MCP_PORT || '3000');
const baseUrl = `http://127.0.0.1:${port}`;
const serverEnv = {
  ...process.env,
  MCP_HOST: '127.0.0.1',
  MCP_PORT: String(port),
};
const initProtocolVersions = ['2025-06-18', '2025-03-26', '2024-11-05'];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForHealth(timeoutMs) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) {
        return;
      }
    } catch {
      // keep polling until the server is ready or exits
    }

    await sleep(1000);
  }

  throw new Error(`Health endpoint did not become ready at ${baseUrl}/health`);
}

async function postJson(body, extraHeaders = {}) {
  const response = await fetch(`${baseUrl}/`, {
    method: 'POST',
    headers: {
      accept: 'application/json, text/event-stream',
      'content-type': 'application/json',
      ...extraHeaders,
    },
    body: JSON.stringify(body),
  });

  const text = await response.text();
  const ssePayload = text
    .split(/\r?\n/)
    .filter((line) => line.startsWith('data:'))
    .map((line) => line.slice(5).trimStart())
    .join('\n');
  const candidate = ssePayload || text.trim();
  let payload;
  try {
    payload = candidate ? JSON.parse(candidate) : {};
  } catch (error) {
    throw new Error(`Non-JSON MCP response (${response.status}): ${text || error}`);
  }

  return { response, payload };
}

async function initializeSession() {
  for (const protocolVersion of initProtocolVersions) {
    const { response, payload } = await postJson({
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion,
        capabilities: {},
        clientInfo: {
          name: 'fib-docker-smoke',
          version: '1.0.0',
        },
      },
    });

    const sessionId = response.headers.get('mcp-session-id');
    if (response.ok && payload?.result && sessionId) {
      return { payload, sessionId, protocolVersion };
    }
  }

  throw new Error('Unable to initialize an MCP session with any supported protocol version');
}

async function main() {
  const expectedVersion = JSON.parse(await readFile('/app/package.json', 'utf8')).version;
  const server = spawn('node', ['/app/build/serverHttp.js'], {
    env: serverEnv,
    stdio: 'inherit',
  });

  const exitPromise = new Promise((resolve, reject) => {
    server.once('error', reject);
    server.once('exit', (code, signal) => {
      if (code === 0 || signal === 'SIGTERM') {
        resolve();
        return;
      }
      reject(new Error(`Server exited before smoke test completed (code=${code}, signal=${signal})`));
    });
  });

  const cleanup = async () => {
    if (server.exitCode === null && !server.killed) {
      server.kill('SIGTERM');
      await Promise.race([exitPromise.catch(() => {}), sleep(5000)]);
      if (server.exitCode === null) {
        server.kill('SIGKILL');
        await exitPromise.catch(() => {});
      }
    }
  };

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      await cleanup();
      process.exit(1);
    });
  }

  try {
    await Promise.race([waitForHealth(30000), exitPromise]);

    const { payload: initPayload, sessionId, protocolVersion } = await initializeSession();
    const serverInfo = initPayload?.result?.serverInfo;
    if (serverInfo?.name !== 'ebay-mcp' || serverInfo?.version !== expectedVersion) {
      throw new Error(`Unexpected initialize response: ${JSON.stringify(initPayload)}`);
    }

    const initNotification = await postJson(
      {
        jsonrpc: '2.0',
        method: 'notifications/initialized',
      },
      { 'mcp-session-id': sessionId },
    );
    if (!initNotification.response.ok) {
      throw new Error(`Initialized notification failed: ${JSON.stringify(initNotification.payload)}`);
    }

    const { payload: toolsPayload, response: toolsResponse } = await postJson(
      {
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/list',
        params: {},
      },
      { 'mcp-session-id': sessionId },
    );

    if (!toolsResponse.ok || !Array.isArray(toolsPayload?.result?.tools) || toolsPayload.result.tools.length === 0) {
      throw new Error(`tools/list failed: ${JSON.stringify(toolsPayload)}`);
    }

    console.log(
      `Smoke OK: initialized ${serverInfo.name}@${serverInfo.version} with protocol ${protocolVersion} and ${toolsPayload.result.tools.length} tool(s)`,
    );
  } finally {
    await cleanup();
  }
}

await main();
