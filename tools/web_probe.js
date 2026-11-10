// Measurement probe (not shipped): counts WebGL2 memory and work, wasm memory. Injected before the engine script.
// ?ios=1 hides the desktop texture-compression extensions (an iPhone's WebGL2 has no S3TC/BPTC/RGTC).
(function () {
	var IOS = /[?&]ios=1/.test(location.search);
	var DPR = /[?&]dpr=(\d+(\.\d+)?)/.exec(location.search); if (DPR) { Object.defineProperty(window, 'devicePixelRatio', { configurable: true, get: function () { return +DPR[1]; } }); }
	var P = window.bcP = { tex: new Map(), rb: new Map(), buf: new Map(), programs: 0, shaders: 0, linkMs: 0, draws: 0,
		frames: [], wasm: null, ext: [], hidden: [], log: [], fmt: {} };
	var SZ = { 0x8058: 4, 0x8C43: 4, 0x881A: 8, 0x8814: 16, 0x8229: 1, 0x822B: 2, 0x822D: 2, 0x822F: 4, 0x822E: 4,
		0x88F0: 4, 0x81A6: 4, 0x8CAC: 4, 0x8CAD: 8, 0x81A5: 2, 0x8059: 4, 0x8C3A: 4, 0x8C3D: 4, 0x8051: 3, 0x8D62: 2,
		0x8230: 8, 0x881B: 6, 0x8815: 12, 0x8232: 1, 0x8D7C: 4, 0x8D8E: 4 };
	function bpp(ifmt, type) { if (SZ[ifmt]) { return SZ[ifmt]; } if (type === 0x140B || type === 0x1406) { return type === 0x1406 ? 16 : 8; } return 4; }
	function sum(m) { var s = 0; m.forEach(function (v) { s += typeof v === 'number' ? v : v.bytes; }); return s; }
	var DESKTOP = /s3tc|bptc|rgtc/i;
	var origGet = HTMLCanvasElement.prototype.getContext;
	HTMLCanvasElement.prototype.getContext = function (type, attrs) {
		var gl = origGet.apply(this, arguments);
		if (!gl || type !== 'webgl2' || gl.__bc) { return gl; }
		gl.__bc = true; P.gl = gl; P.canvas = this; P.attrs = attrs;
		var bound = {}, unit = 0, boundRb = null, boundBuf = {};
		function tkey() { return bound[unit + ':' + cur]; }
		var cur = 0;
		function texOf(target) { var t = target >= 0x8515 && target <= 0x851A ? 0x8513 : target; return bound[unit + ':' + t]; }
		function rec(target, level, w, h, d, bytes, ifmt) {
			var t = texOf(target); if (!t) { return; }
			var e = P.tex.get(t) || { bytes: 0, parts: {}, w: w, h: h, f: ifmt }; var k = target + ':' + level;
			e.bytes -= e.parts[k] || 0; e.parts[k] = bytes; e.bytes += bytes; if (level === 0) { e.w = w; e.h = h; e.f = ifmt; }
			P.tex.set(t, e);
		}
		var w = function (name, fn) { var o = gl[name].bind(gl); gl[name] = function () { return fn(o, arguments); }; };
		w('getSupportedExtensions', function (o) { var l = o() || []; P.ext = l; return IOS ? l.filter(function (x) { return !DESKTOP.test(x); }) : l; });
		w('getExtension', function (o, a) { if (IOS && DESKTOP.test(a[0])) { P.hidden.push(a[0]); return null; } return o(a[0]); });
		w('activeTexture', function (o, a) { unit = a[0] - 0x84C0; return o(a[0]); });
		w('bindTexture', function (o, a) { bound[unit + ':' + a[0]] = a[1]; return o(a[0], a[1]); });
		w('deleteTexture', function (o, a) { P.tex.delete(a[0]); return o(a[0]); });
		w('texStorage2D', function (o, a) { var L = a[1], W = a[3], H = a[4], b = 0, faces = a[0] === 0x8513 ? 6 : 1;
			for (var i = 0; i < L; i++) { b += Math.max(1, W >> i) * Math.max(1, H >> i) * bpp(a[2]); }
			var t = bound[unit + ':' + a[0]]; if (t) { P.tex.set(t, { bytes: b * faces, parts: {}, w: W, h: H, f: a[2], storage: 1 }); }
			P.fmt[a[2]] = (P.fmt[a[2]] || 0) + 1; return o.apply(null, a); });
		w('texStorage3D', function (o, a) { var L = a[1], b = 0; for (var i = 0; i < L; i++) { b += Math.max(1, a[3] >> i) * Math.max(1, a[4] >> i) * a[5] * bpp(a[2]); }
			var t = bound[unit + ':' + a[0]]; if (t) { P.tex.set(t, { bytes: b, parts: {}, w: a[3], h: a[4], f: a[2], storage: 1 }); } return o.apply(null, a); });
		w('texImage2D', function (o, a) { if (a.length >= 8) { rec(a[0], a[1], a[3], a[4], 1, a[3] * a[4] * bpp(a[2], a[7]), a[2]); P.fmt[a[2]] = (P.fmt[a[2]] || 0) + 1; } return o.apply(null, a); });
		w('texImage3D', function (o, a) { rec(a[0], a[1], a[3], a[4], a[5], a[3] * a[4] * a[5] * bpp(a[2], a[8]), a[2]); return o.apply(null, a); });
		w('compressedTexImage2D', function (o, a) { var d = a[6]; var n = a.length > 7 && a[8] ? a[8] : (d && d.byteLength) || 0; rec(a[0], a[1], a[3], a[4], 1, n, a[2]); P.fmt['c' + a[2]] = (P.fmt['c' + a[2]] || 0) + 1; return o.apply(null, a); });
		w('framebufferTexture2D', function (o, a) { (P.fboT = P.fboT || new Set()).add(a[3]); return o.apply(null, a); });   // render targets
		w('bindRenderbuffer', function (o, a) { boundRb = a[1]; return o(a[0], a[1]); });
		w('deleteRenderbuffer', function (o, a) { P.rb.delete(a[0]); return o(a[0]); });
		w('renderbufferStorage', function (o, a) { P.rb.set(boundRb, a[2] * a[3] * bpp(a[1])); return o.apply(null, a); });
		w('renderbufferStorageMultisample', function (o, a) { P.rb.set(boundRb, a[3] * a[4] * bpp(a[2]) * Math.max(1, a[1])); return o.apply(null, a); });
		w('bindBuffer', function (o, a) { boundBuf[a[0]] = a[1]; return o(a[0], a[1]); });
		w('deleteBuffer', function (o, a) { P.buf.delete(a[0]); return o(a[0]); });
		w('bufferSubData', function (o, a) { P.sub = (P.sub || 0) + 1; return o.apply(null, a); });
		w('bufferData', function (o, a) { var b = boundBuf[a[0]]; if (b) { P.buf.set(b, typeof a[1] === 'number' ? a[1] : (a.length >= 5 && a[4] ? a[4] : (a[1] ? a[1].byteLength - (a[3] || 0) : 0))); } return o.apply(null, a); });
		w('linkProgram', function (o, a) { var t = performance.now(); var r = o(a[0]); P.linkMs += performance.now() - t; P.programs++; return r; });
		w('compileShader', function (o, a) { P.shaders++; return o(a[0]); });
		['drawArrays', 'drawElements', 'drawArraysInstanced', 'drawElementsInstanced', 'drawRangeElements'].forEach(function (n) { w(n, function (o, a) { P.draws++; return o.apply(null, a); }); });
		this.addEventListener('webglcontextlost', function () { P.log.push('CONTEXT LOST ' + (performance.now() / 1000).toFixed(1)); });
		return gl;
	};
	var oi = WebAssembly.instantiate, ois = WebAssembly.instantiateStreaming;
	function grab(r) { var inst = r && (r.instance || r); try { if (inst.exports && inst.exports.memory) { P.wasm = inst.exports.memory; } } catch (e) {} return r; }
	WebAssembly.instantiate = function () { return oi.apply(this, arguments).then(grab); };
	if (ois) { WebAssembly.instantiateStreaming = function () { return ois.apply(this, arguments).then(grab); }; }
	var last = 0, lastT = performance.now();
	function tick() { var t = performance.now(); P.frames.push([t - lastT, P.draws - last]); if (P.frames.length > 120) { P.frames.shift(); } last = P.draws; lastT = t; requestAnimationFrame(tick); }
	requestAnimationFrame(tick);
	// Textures grouped by size and format, render targets marked RT: [[MB, count, 'RT 1125x2436 0x881a'], ...]
	window.bcGroups = function () {
		var g = {}; P.tex.forEach(function (v, k) { var key = (P.fboT && P.fboT.has(k) ? 'RT ' : '') + v.w + 'x' + v.h + ' 0x' + (v.f || 0).toString(16);
			g[key] = g[key] || [0, 0]; g[key][0]++; g[key][1] += v.bytes; });
		return Object.keys(g).map(function (k) { return [+(g[k][1] / 1048576).toFixed(2), g[k][0], k]; }).sort(function (a, b) { return b[0] - a[0]; });
	};
	// Peak per scene (window.bcScene) of textures + render buffers + buffers, sampled every 250 ms
	window.bcPeak = {};
	setInterval(function () { if (!P.gl) { return; } var r = window.bcProbe(), tot = r.texMB + r.rbMB + r.bufMB, s = window.bcScene || 'loading', p = window.bcPeak[s];
		if (!p || tot > p.tot) { window.bcPeak[s] = { tot: +tot.toFixed(1), tex: r.texMB, texN: r.texCount, rt: r.rtMB, rb: r.rbMB, buf: r.bufMB, wasm: r.wasmMB, draws: r.drawsPerFrame, canvas: r.canvas }; } }, 250);
	window.bcProbe = function () {
		var f = P.frames.slice(-30), dc = 0, ms = 0; f.forEach(function (x) { ms += x[0]; dc += x[1]; });
		var top = []; P.tex.forEach(function (v, k) { top.push([v.bytes, v.w + 'x' + v.h, '0x' + (v.f || 0).toString(16), P.fboT && P.fboT.has(k) ? 'RT' : 'asset']); }); top.sort(function (a, b) { return b[0] - a[0]; });
		var MB = function (n) { return +(n / 1048576).toFixed(1); };
		return { t: +(performance.now() / 1000).toFixed(1), dpr: devicePixelRatio, css: innerWidth + 'x' + innerHeight,
			canvas: P.canvas ? P.canvas.width + 'x' + P.canvas.height : null, attrs: P.attrs, ios: IOS, hidden: P.hidden.length,
			wasmMB: P.wasm ? MB(P.wasm.buffer.byteLength) : null,
			jsHeapMB: performance.memory ? MB(performance.memory.usedJSHeapSize) : null,
			texCount: P.tex.size, texMB: MB(sum(P.tex)), rbCount: P.rb.size, rbMB: MB(sum(P.rb)), bufCount: P.buf.size, bufMB: MB(sum(P.buf)),
			programs: P.programs, shaders: P.shaders, linkMs: Math.round(P.linkMs), drawsPerFrame: f.length ? Math.round(dc / f.length) : 0, drawsTotal: P.draws, rafFrames: P.frames.length,
			frameMs: f.length ? +(ms / f.length).toFixed(1) : 0, topTex: top.slice(0, 20).map(function (x) { return MB(x[0]) + 'MB ' + x[1] + ' ' + x[2] + ' ' + x[3]; }),
			rtMB: MB(top.filter(function (x) { return x[3] === 'RT'; }).reduce(function (a, x) { return a + x[0]; }, 0)), phone: window.bcPhone || null,
			fmt: P.fmt, log: P.log };
	};
}());
