"""Smoke-test a deployed web build against the folder it was deployed from (docs/tech/04-deploy.md).
    python tools/web_smoke.py <base url> <web out dir> [--local]
--local: the folder served by `python -m http.server` (no Vercel headers, no Range): files and sizes only.
Checks, with curl-level HTTP only (no browser):
  - index.html answers 200, is the one in the folder (same bc-<hash> tag) and is served no-cache;
  - every file of the folder answers 200 (small files: same byte size);
  - the hashed heavy files (bc-*.wasm/.pck/.js) are served immutable and answer a Range request with 206
    (the shell guard resumes a broken download with Range, docs/tech/03-web-build.md);
  - the audio worklets and push-sw.js are there, and the service worker imports push-sw.js.
Deployment URLs sit behind Vercel Authentication (302 to a login). The script gets the project's
"Protection Bypass for Automation" secret from the Vercel API with VERCEL_TOKEN (+ VERCEL_PROJECT_ID, VERCEL_ORG_ID),
or takes VERCEL_AUTOMATION_BYPASS_SECRET as given; the secret is never printed.
Exit 0 = all good; prints one line per check."""
import json, os, re, sys, urllib.request, urllib.error

BYPASS = ''
SKIP = {'vercel.json'}
fails = []


def get(url, rng=None):
    h = {'Accept-Encoding': 'identity', 'User-Agent': 'bc-web-smoke'}
    if BYPASS:
        h['x-vercel-protection-bypass'] = BYPASS
    if rng:
        h['Range'] = rng
    req = urllib.request.Request(url, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, b''


def bypass_secret():
    """The automation-bypass secret: from the environment, else from the project via the Vercel API."""
    if os.environ.get('VERCEL_AUTOMATION_BYPASS_SECRET'):
        return os.environ['VERCEL_AUTOMATION_BYPASS_SECRET']
    tok, pid, org = (os.environ.get(k, '') for k in ('VERCEL_TOKEN', 'VERCEL_PROJECT_ID', 'VERCEL_ORG_ID'))
    if not (tok and pid):
        return ''
    url = 'https://api.vercel.com/v9/projects/%s%s' % (pid, '?teamId=' + org if org else '')
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + tok})
    try:
        proj = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        print('web_smoke: Vercel API answered %s for the project; no bypass secret' % e.code)
        return ''
    for secret, meta in (proj.get('protectionBypass') or {}).items():
        if (meta or {}).get('scope') == 'automation-bypass':
            return secret
    print('web_smoke: project has no "Protection Bypass for Automation" secret (Settings > Deployment Protection)')
    return ''


def check(ok, what):
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok:
        fails.append(what)


def main():
    global BYPASS
    base, out = sys.argv[1].rstrip('/'), sys.argv[2]
    if not base.startswith('https://bc-tamagotchi.vercel.app') and 'blackcabin.app' not in base:
        BYPASS = bypass_secret()
    names = sorted(f for f in os.listdir(out)
                   if f not in SKIP and not f.startswith('.') and os.path.isfile(os.path.join(out, f)))
    local_index = open(os.path.join(out, 'index.html'), encoding='utf-8').read()
    tag = re.search(r'bc-[0-9a-f]{8}', local_index).group(0)
    st, hd, body = get(base + '/')
    check(st == 200 and tag in body.decode('utf-8', 'replace'), '/ -> 200 with %s (got %s)' % (tag, st))
    local = '--local' in sys.argv
    if not local:
        check('no-cache' in (hd.get('Cache-Control') or ''), '/ Cache-Control no-cache (%s)' % hd.get('Cache-Control'))
    for n in names:
        path = os.path.join(out, n)
        size = os.path.getsize(path)
        if n.startswith(tag) and n.split('.')[-1] in ('wasm', 'pck', 'js') and size > 1_000_000 and not local:
            st, hd, body = get(base + '/' + n, 'bytes=0-15')
            total = (hd.get('Content-Range') or '').split('/')[-1]
            check(st == 206 and total == str(size), '%s Range -> 206, total %s (got %s, %s)' % (n, size, st, total))
            check('immutable' in (hd.get('Cache-Control') or ''), '%s immutable' % n)
        else:
            st, hd, body = get(base + '/' + n)
            check(st == 200 and len(body) == size, '%s -> 200, %d bytes (got %s, %d)' % (n, size, st, len(body)))
    check(any(n.startswith(tag + '.audio.') for n in names) or not any('.audio.' in n for n in names),
          'audio worklets carry the hash tag')
    check('push-sw.js' in names, 'push-sw.js in the build')
    st, hd, body = get(base + '/index.service.worker.js')
    check(st == 200 and b"importScripts('push-sw.js')" in body, 'service worker imports push-sw.js')
    print('web_smoke: %s, %d file(s), %s' % (base, len(names), 'OK' if not fails else '%d FAIL' % len(fails)))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
