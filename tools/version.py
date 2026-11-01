"""Stamp the build: write game/build_info.json (gitignored) with the short commit SHA, a dirty flag and the UTC date,
read from git. The game shows it next to the version ("v0.2.0 · 33dc5b9", plus " · dirty") through
game/scripts/version_info.gd; without the file it shows the version only. Run from anywhere:
    python tools/version.py          # write the stamp
    python tools/version.py --print  # show what would be written, write nothing
"Dirty" means uncommitted changes (tracked or untracked) under game/, i.e. the build is not exactly the commit.
See docs/tech/versioning.md."""
import datetime, io, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'game', 'build_info.json')


def git(*args):
    return subprocess.run(['git', '-C', ROOT] + list(args), capture_output=True, text=True, encoding='utf-8').stdout.strip()


def stamp():
    return {
        'sha': git('rev-parse', '--short', 'HEAD'),
        'dirty': bool(git('status', '--porcelain', '--', 'game')),
        'date': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d'),
    }


if __name__ == '__main__':
    s = stamp()
    if not s['sha']:
        sys.exit('version.py: no git commit found')
    text = json.dumps(s, indent=2) + '\n'
    if '--print' in sys.argv:
        print(text, end='')
    else:
        io.open(OUT, 'w', encoding='utf-8', newline='\n').write(text)
        print('wrote', OUT, s)
