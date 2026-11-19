// Drives a throwaway headless Chrome (temp profile) through CDP: opens the local push receiver page, grants
// notifications, clicks Subscribe, waits for READY, then waits for a push to reach the service worker.
// Usage: node push_cdp.mjs <debug-port> <phase: subscribe|wait>
const port = process.argv[2] || '9333';
const phase = process.argv[3] || 'subscribe';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function target() {
  for (let i = 0; i < 50; i++) {
    try {
      const l = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const t = l.find((x) => x.type === 'page' && x.url.includes('8793'));
      if (t) return t;
    } catch {}
    await sleep(300);
  }
  throw new Error('no page');
}

const t = await target();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
ws.onmessage = (m) => {
  const d = JSON.parse(m.data);
  if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); }
};
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async (expr) => (await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true })).result?.result?.value;

if (phase === 'subscribe') {
  await send('Browser.grantPermissions', { origin: 'http://localhost:8793', permissions: ['notifications'] });
  await ev("document.getElementById('go').click(); true");
  for (let i = 0; i < 60; i++) {
    const log = await ev("(window.bcLog||[]).join('\\n')");
    if (log && (log.includes('READY') || log.includes('ERROR') || log.includes('failed'))) {
      console.log(log);
      console.log('UID=' + (await ev('window.bcUid||""')));
      break;
    }
    await sleep(500);
  }
} else {
  for (let i = 0; i < 60; i++) {
    const got = await ev('window.bcPushGot ? JSON.stringify(window.bcPushGot) : ""');
    if (got) { console.log('PUSH ' + got); break; }
    await sleep(500);
  }
  console.log((await ev("(window.bcLog||[]).slice(-3).join('\\n')")) || '');
}
ws.close();
process.exit(0);
