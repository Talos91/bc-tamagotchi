"""One-command web build: stamp the version, import, export the "Web" preset into web/, content-hash the heavy
files, write web/vercel.json. From a clean state (no web/, no game/.godot):
    python tools/build_web.py            # build into web/
    python tools/build_web.py --deploy   # build, then `vercel deploy --prod` (project bc-tamagotchi; needs `npx vercel login` once)
Needs the Godot 4.6.1 web templates in %APPDATA%/Godot/export_templates/4.6.1.stable (see docs/tech/03-web-build.md).
Heavy files (wasm, pck, js) are renamed to bc-<hash8>.* so they can be cached for a year; index.html, the service
worker and the manifest are served no-cache, so a new deploy is picked up on the next load."""
import hashlib, io, json, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, 'game')
WEB = os.path.join(ROOT, 'web')
GODOT = os.environ.get('GODOT', 'H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64_console.exe')
PRESET = 'Web'
HEAVY = ('wasm', 'pck', 'js')


def run(*cmd):
    print('>', ' '.join(cmd))
    subprocess.run(list(cmd), check=True)


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
    for name in ('index.html', 'index.service.worker.js'):
        p = os.path.join(WEB, name)
        s = read(p)
        for ext in HEAVY:
            s = s.replace('index.' + ext, tag + '.' + ext)
        s = re.sub(r'"executable"\s*:\s*"index"', '"executable":"%s"' % tag, s)
        write(p, s)
    return tag


def vercel_json():
    long_cache = [{'key': 'Cache-Control', 'value': 'public, max-age=31536000, immutable'}]
    no_cache = [{'key': 'Cache-Control', 'value': 'no-cache, must-revalidate'}]
    cfg = {
        'cleanUrls': False,
        'headers': [
            {'source': '/bc-(.*)\.(wasm|pck|js)', 'headers': long_cache},
            {'source': '/(index\.html|index\.service\.worker\.js|index\.manifest\.json|)', 'headers': no_cache},
            {'source': '/(.*)\.(png|ico)', 'headers': [{'key': 'Cache-Control', 'value': 'public, max-age=86400'}]},
        ],
    }
    write(os.path.join(WEB, 'vercel.json'), json.dumps(cfg, indent=2) + '\n')


def main():
    run(sys.executable, os.path.join(ROOT, 'tools', 'version.py'))
    shutil.rmtree(WEB, ignore_errors=True)
    os.makedirs(WEB)
    run(GODOT, '--headless', '--path', GAME, '--import')
    run(GODOT, '--headless', '--path', GAME, '--export-release', PRESET, os.path.join(WEB, 'index.html'))
    if not os.path.exists(os.path.join(WEB, 'index.html')):
        sys.exit('build_web: export produced no index.html (are the 4.6.1 web templates installed?)')
    tag = hash_rename()
    vercel_json()
    size = sum(os.path.getsize(os.path.join(WEB, f)) for f in os.listdir(WEB))
    print('built web/ (%s, %.1f MB)' % (tag, size / 1e6))
    if '--deploy' in sys.argv:
        run('npx', '--yes', 'vercel', 'link', '--yes', '--project', 'bc-tamagotchi', '--cwd', WEB)
        run('npx', '--yes', 'vercel', 'deploy', '--prod', '--yes', '--cwd', WEB)


if __name__ == '__main__':
    main()
