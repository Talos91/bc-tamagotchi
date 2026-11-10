"""One-command web build: stamp the version, import, export the "Web" preset into web/, content-hash the heavy
files, write web/vercel.json. From a clean state (no web/, no game/.godot):
    python tools/build_web.py            # build into web/
    python tools/build_web.py --out <dir>   # build into <dir> instead of web/ (use a folder outside Google Drive)
    python tools/build_web.py --deploy   # build, then `vercel deploy --prod` (project bc-tamagotchi; needs `npx vercel login` once)
Needs the Godot 4.6.1 web templates in %APPDATA%/Godot/export_templates/4.6.1.stable (see docs/tech/03-web-build.md).
Heavy files (wasm, pck, js) are renamed to bc-<hash8>.* so they can be cached for a year; index.html, the service
worker and the manifest are served no-cache, so a new deploy is picked up on the next load."""
import hashlib, io, json, os, re, shutil, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, 'game')
WEB = os.path.join(ROOT, 'web')
GODOT = os.environ.get('GODOT', 'H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64_console.exe')
PRESET = 'Web'
HEAVY = ('wasm', 'pck', 'js')


# Injected before the engine script: says in words why the game did not start (the next iPhone report then carries
# the reason). Plain ES5-ish JS, no optional chaining, so even an old Safari runs it. Shows a banner over the page;
# tapping it hides it. "BC-DIAG" line in the banner = copyable one-liner for a screenshot.
SHELL_GUARD = r'''<script>
(function () {
	var msgs = [], box = null, title = '';
	function ua() { return (navigator.userAgent || '').replace(/^Mozilla\/5.0 /, ''); }
	function show() {
		if (!document.body) { document.addEventListener('DOMContentLoaded', show); return; }
		if (!box) {
			box = document.createElement('div');
			box.id = 'bc-diag';
			box.setAttribute('style', 'position:fixed;left:0;right:0;top:0;z-index:99999;background:#5b1f2a;color:#fff;font:13px/1.35 -apple-system,Arial,sans-serif;padding:12px 14px;max-height:70%;overflow:auto;white-space:pre-wrap;word-break:break-word');
			var txt = document.createElement('div'); txt.id = 'bc-diag-text';
			var btn = document.createElement('button'); btn.id = 'bc-diag-reload'; btn.textContent = 'Reload';
			btn.setAttribute('style', 'margin-top:10px;font:600 15px -apple-system,Arial,sans-serif;padding:10px 22px;border:0;border-radius:8px;background:#fff;color:#5b1f2a');
			btn.addEventListener('click', function (e) { e.stopPropagation(); location.reload(); });
			box.appendChild(txt); box.appendChild(btn);
			box.addEventListener('click', function () { box.style.display = 'none'; });
			document.body.appendChild(box);
		}
		box.style.display = 'block';
		document.getElementById('bc-diag-text').textContent = (title || 'Black Cabin could not start') + ' (tap to hide)\n\n' + msgs.join('\n') + '\n\nBC-DIAG ' + ua();
	}
	function fail(m) { if (msgs.indexOf(m) < 0) { msgs.push(m); } show(); }
	window.bcFail = fail;
	// Download watch + resume (item 28: iPhone "Load failed" at ~45 %). The engine reads the 37 MB wasm / 16 MB pck as
	// one long stream and does not catch a network error in the middle of it, so one dropped connection killed the
	// start with a bare "Load failed" and no retry. This wraps fetch() for the two big files only: it records file,
	// HTTP status, encoding and bytes received (named in the banner), and when the stream breaks it resumes from the
	// byte already received with a Range request (the server answers ranges with plain bytes, so offsets match).
	var net = { file: '', status: '', enc: '', got: 0, resumes: 0, err: '' };
	function mb(n) { return (n / 1048576).toFixed(1) + ' MB'; }
	function netInfo() {
		return net.file ? ('Last download: ' + net.file + ' HTTP ' + net.status + (net.enc ? ' ' + net.enc : '') + ', ' + mb(net.got) + ' received' + (net.resumes ? ', resumed ' + net.resumes + 'x' : '') + (net.err ? ', error: ' + net.err : '')) : 'No game file download had started.';
	}
	var origFetch = window.fetch;
	if (typeof origFetch === 'function' && typeof ReadableStream === 'function') {
		window.fetch = function (input, init) {
			var url = typeof input === 'string' ? input : (input && input.url) || '';
			var m = /(bc-[0-9a-f]{8}\.(wasm|pck))(\?|$)/.exec(url);
			if (!m || init) { return origFetch.apply(this, arguments); }
			var name = m[1], got = 0, reader = null, resumes = 0, tries = 0;
			net = { file: name, status: '', enc: '', got: 0, resumes: 0, err: '' };
			function open(range) {
				return origFetch(url, range ? { headers: { Range: 'bytes=' + got + '-' } } : undefined).then(function (r) {
					net.status = r.status; net.enc = r.headers.get('Content-Encoding') || '';
					if (!(range ? r.status === 206 : r.ok)) { var e = new Error('HTTP ' + r.status); e.http = true; throw e; }
					return r;
				});
			}
			function again(err, c) {
				net.err = String(err && err.message ? err.message : err); net.resumes = ++resumes;
				if (resumes > 8 || (err && err.http && !got)) {
					fail('Game file ' + name + ' could not be downloaded.\n' + netInfo());
					throw err;
				}
				return new Promise(function (ok) { setTimeout(ok, Math.min(4000, 700 * resumes)); }).then(function () {
					return open(got > 0).then(function (r) { reader = r.body.getReader(); net.err = ''; return pump(c); }, function (e2) { return again(e2, c); });
				});
			}
			function pump(c) {
				return reader.read().then(function (r) {
					if (r.done) { c.close(); return; }
					got += r.value.length; net.got = got; c.enqueue(r.value);
					return pump(c);
				}, function (err) { return again(err, c); });
			}
			return open(false).then(function (r) {
				reader = r.body.getReader();
				var h = new Headers(); h.set('Content-Type', r.headers.get('Content-Type') || 'application/octet-stream');
				return new Response(new ReadableStream({ start: function (c) { return pump(c).catch(function (e) { c.error(e); }); } }), { status: 200, headers: h });
			}, function (err) {
				if (tries++ < 3) { return new Promise(function (ok) { setTimeout(ok, 800 * tries); }).then(function () { return window.fetch(input, init); }); }
				net.err = String(err && err.message ? err.message : err);
				fail('Game file ' + name + ' could not be downloaded.\n' + netInfo()); throw err;
			});
		};
	}
	// GPU and memory tally for the context-loss banner (item 29: an iPhone lost the WebGL context at the start screen
	// and the engine only said "please reload"). Counts what the engine uploads to the WebGL2 context: textures
	// (texStorage2D/3D, texImage2D/3D, compressed), render buffers, and the wasm heap; cheap (upload calls only).
	var gpu = { tex: new Map(), rb: new Map(), rbBound: null, canvas: null, mem: null, t0: Date.now() };
	var BPP = { 0x8058: 4, 0x8C43: 4, 0x881A: 8, 0x8814: 16, 0x8229: 1, 0x822B: 2, 0x822D: 2, 0x822F: 4, 0x822E: 4, 0x88F0: 4,
		0x81A6: 4, 0x8CAC: 4, 0x8CAD: 8, 0x81A5: 2, 0x8059: 4, 0x8C3A: 4, 0x8051: 3, 0x8D62: 2, 0x8230: 8, 0x881B: 6, 0x8815: 12 };
	function bpp(f, type) { return BPP[f] || (type === 0x1406 ? 16 : type === 0x140B ? 8 : 4); }
	function total(m) { var n = 0; m.forEach(function (v) { n += v.b; }); return n; }
	try {
		var origCtx = HTMLCanvasElement.prototype.getContext;
		HTMLCanvasElement.prototype.getContext = function (type) {
			var gl = origCtx.apply(this, arguments);
			if (!gl || type !== 'webgl2' || gl.bcTally) { return gl; }
			gl.bcTally = true; gpu.canvas = this;
			var unit = 0, bound = {};
			function on(name, fn) { var o = gl[name]; if (typeof o !== 'function') { return; } gl[name] = function () { try { fn(arguments); } catch (x) {} return o.apply(gl, arguments); }; }
			function texOf(t) { return bound[unit + ':' + (t >= 0x8515 && t <= 0x851A ? 0x8513 : t)]; }
			function put(t, key, bytes) { var x = texOf(t); if (!x) { return; } var e = gpu.tex.get(x) || { b: 0, p: {} }; e.b += bytes - (e.p[key] || 0); e.p[key] = bytes; gpu.tex.set(x, e); }
			on('activeTexture', function (a) { unit = a[0] - 0x84C0; });
			on('bindTexture', function (a) { bound[unit + ':' + a[0]] = a[1]; });
			on('deleteTexture', function (a) { gpu.tex.delete(a[0]); });
			on('texStorage2D', function (a) { var b = 0; for (var i = 0; i < a[1]; i++) { b += Math.max(1, a[3] >> i) * Math.max(1, a[4] >> i) * bpp(a[2]); } put(a[0], 's', b * (a[0] === 0x8513 ? 6 : 1)); });
			on('texStorage3D', function (a) { var b = 0; for (var i = 0; i < a[1]; i++) { b += Math.max(1, a[3] >> i) * Math.max(1, a[4] >> i) * a[5] * bpp(a[2]); } put(a[0], 's', b); });
			on('texImage2D', function (a) { if (a.length >= 8) { put(a[0], a[0] + ':' + a[1], a[3] * a[4] * bpp(a[2], a[7])); } });
			on('texImage3D', function (a) { put(a[0], a[0] + ':' + a[1], a[3] * a[4] * a[5] * bpp(a[2], a[8])); });
			on('compressedTexImage2D', function (a) { put(a[0], a[0] + ':' + a[1], a[8] || (a[6] && a[6].byteLength) || 0); });
			on('bindRenderbuffer', function (a) { gpu.rbBound = a[1]; });
			on('deleteRenderbuffer', function (a) { gpu.rb.delete(a[0]); });
			on('renderbufferStorage', function (a) { gpu.rb.set(gpu.rbBound, { b: a[2] * a[3] * bpp(a[1]) }); });
			on('renderbufferStorageMultisample', function (a) { gpu.rb.set(gpu.rbBound, { b: a[3] * a[4] * bpp(a[2]) * Math.max(1, a[1]) }); });
			return gl;
		};
		var origInst = WebAssembly.instantiate, origStream = WebAssembly.instantiateStreaming;
		var grab = function (r) { try { var i = r.instance || r; if (i.exports && i.exports.memory) { gpu.mem = i.exports.memory; } } catch (x) {} return r; };
		WebAssembly.instantiate = function () { return origInst.apply(this, arguments).then(grab); };
		if (origStream) { WebAssembly.instantiateStreaming = function () { return origStream.apply(this, arguments).then(grab); }; }
	} catch (e) {}
	window.bcGpu = function () {
		var c = gpu.canvas, line = [];
		line.push('Textures: ' + gpu.tex.size + ' (' + mb(total(gpu.tex)) + '), render buffers ' + mb(total(gpu.rb)));
		var ph = window.bcPhone, phs = ph ? [ph.dpr ? 'ratio cap ' + PHONE_DPR + ' of ' + ph.real : '', ph.msaa ? 'MSAA off' : '', ph.scale ? '3D 0.75' : ''].filter(function (x) { return x; }).join(', ') : '';
		line.push('Canvas: ' + (c ? c.width + 'x' + c.height : '?') + ' at pixel ratio ' + (window.devicePixelRatio || 1) + '; phone graphics ' + (ph ? 'on' + (phs ? ' (' + phs + ')' : ' (no parts)') : 'off'));
		line.push('Wasm heap: ' + (gpu.mem ? mb(gpu.mem.buffer.byteLength) : '?') + (performance.memory ? ', JS heap ' + mb(performance.memory.usedJSHeapSize) : ''));
		line.push('Last scene: ' + (window.bcScene || 'loading') + ', ' + Math.round((Date.now() - gpu.t0) / 1000) + ' s after the page opened');
		return line.join('\n');
	};
	// Phone graphics (DECISIONS 2026-11-10, Daniele "Yes, allow it"; owner item 33: an iPhone at pixel ratio 3 lost its
	// graphics entering the venue, ~250 MB of WebGL memory of which ~150 MB scale with the screen's pixels). On a touch
	// phone only: the PHONE_PARTS of: pixel ratio cap (the canvas is drawn at most PHONE_DPR device pixels per CSS pixel, the
	// browser stretches it), MSAA off and 3D at 0.75 (both applied by game/scripts/phone_graphics.gd from window.bcPhone).
	// Desktop browsers are unchanged. ?phone=0 / ?phone=1 force it; ?pg=dpr,msaa,scale picks the parts (measuring).
	// Default: ratio cap + MSAA off, the fewest that fit the budget (measured 2026-11-10, report perf-iphone-2.md);
	// 'scale' (3D at 0.75, about -7 MB more) stays available via ?pg=dpr,msaa,scale.
	var PHONE_PARTS = ['dpr', 'msaa'], PHONE_DPR = 2;
	try {
		var q = location.search, coarse = false;
		try { coarse = window.matchMedia('(pointer: coarse)').matches; } catch (x) {}
		var phone = /[?&]phone=1/.test(q) || (!/[?&]phone=0/.test(q) && (navigator.maxTouchPoints || 0) > 0 && coarse);
		var pm = /[?&]pg=([a-z,]*)/.exec(q), parts = pm ? pm[1].split(',') : PHONE_PARTS;
		window.bcPhone = phone ? { dpr: parts.indexOf('dpr') >= 0, msaa: parts.indexOf('msaa') >= 0, scale: parts.indexOf('scale') >= 0 } : null;
		if (phone && window.bcPhone.dpr) {
			var dd = Object.getOwnPropertyDescriptor(window, 'devicePixelRatio') || Object.getOwnPropertyDescriptor(Window.prototype, 'devicePixelRatio');
			var real = function () { return dd && dd.get ? dd.get.call(window) : 1; };
			window.bcPhone.real = real();
			Object.defineProperty(window, 'devicePixelRatio', { configurable: true, get: function () { return Math.min(PHONE_DPR, real()); } });
		}
	} catch (e) { window.bcPhone = null; }
	// Hard requirements, checked before the 50 MB download starts.
	try {
		var c = document.createElement('canvas');
		if (!c.getContext('webgl2')) { fail('WebGL2 is not available in this browser (iOS 15 or newer is needed, and Low Power Mode or a memory-starved tab can switch it off). Try closing other tabs, restarting Safari, or updating iOS.'); }
	} catch (e) { fail('WebGL2 check failed: ' + e); }
	if (typeof WebAssembly !== 'object') { fail('WebAssembly is not available in this browser.'); }
	try { window.localStorage.setItem('bc-probe', '1'); window.localStorage.removeItem('bc-probe'); }
	catch (e) { fail('Browser storage is blocked (private browsing or "Block all cookies"); progress could not be saved. Open the page in a normal tab.'); }
	window.addEventListener('error', function (e) {
		var t = e && e.target;
		if (t && t.src) { fail('A game file failed to load: ' + t.src.split('/').pop()); return; }
		fail('Script error: ' + (e && e.message ? e.message : 'unknown') + (e && e.filename ? ' @' + e.filename.split('/').pop() + ':' + e.lineno : ''));
	}, true);
	window.addEventListener('unhandledrejection', function (e) {
		var r = e && e.reason, m = r && r.message ? r.message : String(r);
		// Audio worklet failures are not fatal: the engine goes on without sound.
		// Same for the PWA service worker (offline cache only; the game runs without it).
		if (/worklet|ServiceWorker/i.test(m)) { try { console.warn('BC audio worklet:', m); } catch (x) {} return; }
		fail('Startup failed: ' + m + '\n' + netInfo());
	});
	// Capture phase on window runs before the engine's own canvas listener, whose bare alert("WebGL context lost,
	// please reload the page") blocked the page; this banner says what was in use instead, with a Reload button.
	window.addEventListener('webglcontextlost', function (e) {
		try { e.preventDefault(); e.stopImmediatePropagation(); } catch (x) {}
		title = 'Black Cabin lost its graphics';
		fail('The phone took the graphics context back (out of graphics memory, or a frame too heavy for it).\n' + window.bcGpu() + '\nReload to continue. If it keeps happening, close other tabs and apps first.');
	}, true);
	// Safari kills a tab that runs out of memory and reloads it silently: leave a trace in sessionStorage so the
	// reloaded page can say so.
	try {
		var s = window.sessionStorage;
		if (s.getItem('bc-started') === '1' && s.getItem('bc-ok') !== '1') {
			fail('The previous start did not finish: the browser probably ran out of memory and reloaded the tab (or the page was reloaded while loading). Close other tabs/apps and try again.');
		}
		s.setItem('bc-started', '1'); s.removeItem('bc-ok');
		window.bcOk = function () { try { s.setItem('bc-ok', '1'); } catch (x) {} };
	} catch (e) { window.bcOk = function () {}; }
	// 25 s without the first frame: say what we know.
	var t0 = Date.now(), warned = false;
	var iv = setInterval(function () {
		var st = document.getElementById('status');
		if (!st || !document.body || !document.body.contains(st)) {
			if (document.body && Date.now() - t0 > 300) { window.bcOk(); clearInterval(iv); if (warned && box) { box.style.display = 'none'; } }
			return;
		}
		if (!warned && Date.now() - t0 > 25000) { warned = true; fail('Still loading after 25 s. Slow connection, or the browser stalled. The 50 MB download needs a stable connection.'); }
	}, 500);
}());
</script>
'''


def npx(*args):
    """npx is npx.cmd on Windows (PowerShell blocks npx.ps1 under the default execution policy)."""
    run('npx.cmd' if os.name == 'nt' else 'npx', '--yes', *args)


def run(*cmd):
    print('>', ' '.join(cmd))
    subprocess.run(list(cmd), check=True)


def clean_web():
    """Empty web/ but keep the folder (a server or Drive sync may hold the folder itself); retry each entry on
    PermissionError/OSError because Google Drive sync holds files briefly."""
    os.makedirs(WEB, exist_ok=True)
    for name in os.listdir(WEB):
        p = os.path.join(WEB, name)
        for attempt in range(10):
            try:
                shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
                break
            except FileNotFoundError:
                break
            except OSError:
                time.sleep(1.5)
        else:
            sys.exit('build_web: could not remove %s (Drive sync or a local server holding it?); retry' % p)


def read(p):
    return io.open(p, encoding='utf-8').read()


def write(p, s):
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)


def hash_rename():
    """index.{wasm,pck,js} -> bc-<hash8>.* and patch index.html / the service worker to match."""
    h = hashlib.sha256()
    for ext in sorted(HEAVY):
        h.update(open(os.path.join(WEB, 'index.' + ext), 'rb').read())
    tag = 'bc-' + h.hexdigest()[:8]
    for ext in HEAVY:
        os.replace(os.path.join(WEB, 'index.' + ext), os.path.join(WEB, tag + '.' + ext))
    # The engine loads the audio worklets as "<executable>.audio.worklet.js", so they must follow the rename
    # (until 2026-11-04 they stayed index.audio.*.js and answered 404 on the live site).
    worklets = [f for f in os.listdir(WEB) if f.startswith('index.audio.') and f.endswith('.js')]
    for f in worklets:
        os.replace(os.path.join(WEB, f), os.path.join(WEB, tag + f[len('index'):]))
    for name in ('index.html', 'index.service.worker.js'):
        p = os.path.join(WEB, name)
        s = read(p)
        for ext in HEAVY:
            s = s.replace('index.' + ext, tag + '.' + ext)
        for f in worklets:
            s = s.replace(f, tag + f[len('index'):])
        s = re.sub(r'"executable"\s*:\s*"index"', '"executable":"%s"' % tag, s)
        if name == 'index.html':
            s = s.replace('<script src="%s.js"></script>' % tag, SHELL_GUARD + '<script src="%s.js"></script>' % tag, 1)
        write(p, s)
    return tag


def vercel_json():
    long_cache = [{'key': 'Cache-Control', 'value': 'public, max-age=31536000, immutable'}]
    no_cache = [{'key': 'Cache-Control', 'value': 'no-cache, must-revalidate'}]
    cfg = {
        'cleanUrls': False,
        'headers': [
            {'source': r'/bc-(.*)\.(wasm|pck|js)', 'headers': long_cache},
            {'source': r'/(index\.html|index\.service\.worker\.js|index\.manifest\.json|)', 'headers': no_cache},
            {'source': r'/(.*)\.(png|ico)', 'headers': [{'key': 'Cache-Control', 'value': 'public, max-age=86400'}]},
        ],
    }
    write(os.path.join(WEB, 'vercel.json'), json.dumps(cfg, indent=2) + '\n')


def main():
    global WEB
    if '--out' in sys.argv:
        WEB = os.path.abspath(os.path.expandvars(sys.argv[sys.argv.index('--out') + 1]))
    run(sys.executable, os.path.join(ROOT, 'tools', 'version.py'))
    clean_web()
    run(GODOT, '--headless', '--path', GAME, '--import')
    run(GODOT, '--headless', '--path', GAME, '--export-release', PRESET, os.path.join(WEB, 'index.html'))
    if not os.path.exists(os.path.join(WEB, 'index.html')):
        sys.exit('build_web: export produced no index.html (are the 4.6.1 web templates installed?)')
    tag = hash_rename()
    vercel_json()
    size = sum(os.path.getsize(os.path.join(WEB, f)) for f in os.listdir(WEB))
    print('built web/ (%s, %.1f MB)' % (tag, size / 1e6))
    if '--deploy' in sys.argv:
        npx('vercel', 'link', '--yes', '--project', 'bc-tamagotchi', '--cwd', WEB)
        npx('vercel', 'deploy', '--prod', '--yes', '--cwd', WEB)


if __name__ == '__main__':
    main()
