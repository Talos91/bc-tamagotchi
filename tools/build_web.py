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
