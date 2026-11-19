// Opens chrome://gcm-internals in the hidden test Chrome and prints its connection state and receive log.
const port = process.argv[2] || '9334';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const t = await (await fetch(`http://127.0.0.1:${port}/json/new?chrome://gcm-internals`, { method: 'PUT' })).json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pending = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); } };
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
await sleep(1500);
await send('Runtime.evaluate', { expression: "var b=document.getElementById('recording');if(b&&!b.checked)b.click();var r=document.getElementById('refresh');if(r)r.click();true" });
await sleep(2500);
const r = await send('Runtime.evaluate', { expression: 'document.body.innerText', returnByValue: true });
console.log(String(r.result?.result?.value || '').slice(0, 3000));
ws.close(); process.exit(0);
