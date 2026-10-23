"""Issue #176: emit bounded coordination work only when checkpoints change.

No model calls, credentials, engine launches, purchases, or gameplay edits.
Nonzero means Maestri must skip the scheduled prompt.
"""
import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / '.bot_runs' / 'ops176_continuity_state.json'
WATCH = [
    '.bot_runs/lua120_defeat_trial_result.json',
    '.bot_runs/lua120_victory_red.log',
    '.bot_runs/lua120_victory_green_explicit.log',
    '.bot_runs/lua120_victory_full_gut_final.log',
    '.bot_runs/lua120_victory_headless.log',
    '.bot_runs/lua120_live_victory_trial_result.json',
    'docs/RELEASE_ROADMAP.md',
    'docs/AGENT_FLEET_POLICY.md',
    'tools/qa_visual_review.py',
]


def main():
    signatures = {}
    for name in WATCH:
        path = ROOT / name
        if path.is_file():
            signatures[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    try:
        previous = json.loads(STATE.read_text(encoding='utf-8')) if STATE.exists() else {}
        if not isinstance(previous, dict) or any(
                not isinstance(name, str) or not isinstance(digest, str)
                or len(digest) != 64 or any(c not in '0123456789abcdef' for c in digest)
                for name, digest in previous.items()):
            raise ValueError('expected checkpoint names mapped to SHA-256 strings')
    except (OSError, ValueError) as error:
        print(f'Continuity state invalid; preserved for review: {error}', file=sys.stderr)
        return 2
    changed = [name for name, digest in signatures.items() if previous.get(name) != digest]
    removed = [name for name in previous if name in WATCH and name not in signatures]
    changed.extend(removed)
    if not changed:
        return 1
    print(json.dumps({'issue': 176, 'changed_checkpoints': changed,
                     'removed_checkpoints': removed,
                     'task': 'Verify these checkpoint files read-only. Check issue status and existing reservations. Report only new evidence to Codex and kanban. Do not launch engine, edit production, repeat completed audits, or recruit. If Codex is unavailable, handle only an already assigned basic task; record advanced work blocked. No paid fallback. Maximum two requests globally per package within ten minutes, never per terminal. Stop immediately on 401/403 or an existing stop order. For 429 at most one retry only if Retry-After is at most 60 seconds and within the same global limit.'}), flush=True)
    STATE.parent.mkdir(exist_ok=True)
    pending = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', newline='\n',
                                         dir=STATE.parent, delete=False) as stream:
            pending = Path(stream.name)
            stream.write(json.dumps(signatures, indent=2) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(pending, STATE)
    finally:
        if pending is not None and pending.exists():
            pending.unlink()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
