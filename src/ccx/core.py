from pathlib import Path
import os, json, shutil, time, tarfile, base64

HOME = Path.home()
XDG_DATA = Path(os.environ.get('XDG_DATA_HOME') or (HOME / '.local/share'))
PROFILES = Path(os.environ.get('CCX_PROFILES') or (XDG_DATA / 'ccx' / 'profiles'))
PROFILES.mkdir(parents=True, exist_ok=True)

CUR_FILE  = PROFILES / '.current'
LAST_FILE = PROFILES / '.last'
DURABLE = os.environ.get('CCX_DURABLE') == '1'


def codex_targets():
    targets = [HOME / '.codex' / 'auth.json']
    code_home = os.environ.get('CODEX_HOME')
    if code_home:
        p = Path(os.path.expanduser(code_home)) / 'auth.json'
        if p not in targets:
            targets.append(p)
    extra = [e for e in os.environ.get('CCX_TARGETS','').split(':') if e.strip()]
    for e in extra:
        p = Path(os.path.expanduser(e.strip()))
        if p not in targets:
            targets.append(p)
    for t in targets:
        t.parent.mkdir(parents=True, exist_ok=True)
    return targets


# --------- FS helpers ---------
def _validated_json(path: Path):
    with open(path, 'rb') as f:
        if f.read(1) != b'{':
            raise ValueError('Not a JSON file')
    json.load(open(path, 'r', encoding='utf-8'))


def _fsync_dir(d: Path):
    try:
        fd = os.open(str(d), os.O_RDONLY)
        os.fsync(fd)
        os.close(fd)
    except Exception:
        pass


def atomic_copy(src: Path, dst: Path):
    _validated_json(src)
    tmp = Path(str(dst) + f'.tmp.{os.getpid()}')
    shutil.copy2(src, tmp)
    if DURABLE:
        try:
            with open(tmp, 'rb') as fh:
                os.fsync(fh.fileno())
            _fsync_dir(tmp.parent)
        except Exception:
            pass
    os.replace(tmp, dst)
    if DURABLE:
        _fsync_dir(Path(dst).parent)


# --------- markers ---------
def read_current():
    return CUR_FILE.read_text(encoding='utf-8').strip() if CUR_FILE.exists() else None


def write_current(v: str):
    CUR_FILE.write_text(v, encoding='utf-8')


def read_last():
    return LAST_FILE.read_text(encoding='utf-8').strip() if LAST_FILE.exists() else None


def write_last(v: str):
    LAST_FILE.write_text(v, encoding='utf-8')


# --------- ops ---------
def list_profiles():
    return sorted([p.stem for p in PROFILES.glob('*.json') if not p.name.startswith('_backup-')], key=str.casefold)


def activate_profile(name: str):
    src = PROFILES / f'{name}.json'
    if not src.exists():
        raise FileNotFoundError('Profile %r not found' % name)
    prev = read_current()
    for t in codex_targets():
        atomic_copy(src, t)
    if prev:
        write_last(prev)
    write_current(name)


def toggle_previous():
    prev = read_last()
    if not prev:
        raise RuntimeError('No previous profile recorded')
    if not (PROFILES / f'{prev}.json').exists():
        raise FileNotFoundError('Previous profile missing')
    activate_profile(prev)


def export_tar(out_path=None):
    ts = time.strftime('%Y%m%d-%H%M%S')
    out = Path(out_path) if out_path else HOME / f'ccx-profiles-{ts}.tar.gz'
    with tarfile.open(out, 'w:gz') as tar:
        for n in list_profiles():
            tar.add(str(PROFILES / f'{n}.json'), arcname=f'{n}.json')
    return out


def import_tar(path):
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError('Tar file not found')
    with tarfile.open(path, 'r:gz') as tar:
        for m in tar.getmembers():
            if not m.name.endswith('.json'):
                continue
            nm = Path(m.name).stem
            dst = PROFILES / f'{nm}.json'
            if dst.exists():
                continue
            f = tar.extractfile(m)
            if not f:
                continue
            data = f.read()
            try:
                json.loads(data.decode('utf-8'))
            except Exception:
                continue
            tmp = Path(str(dst) + f'.tmp.{os.getpid()}')
            tmp.write_bytes(data)
            os.replace(tmp, dst)


def import_from_env(prefix='CCX_AUTH_'):
    import re
    added = 0
    pattern = re.compile(r'^' + re.escape(prefix) + r'(.+)$')
    for k, v in os.environ.items():
        m = pattern.match(k)
        if not m:
            continue
        nm = m.group(1)
        val = v.strip()
        try:
            dst = PROFILES / f'{nm}.json'
            if dst.exists():
                continue
            if val.startswith('b64:'):
                data = base64.b64decode(val[4:].encode('utf-8'))
                obj = json.loads(data.decode('utf-8'))
                dst.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
                added += 1
            elif Path(os.path.expanduser(val)).exists():
                atomic_copy(Path(os.path.expanduser(val)), dst)
                added += 1
            else:
                obj = json.loads(val)
                dst.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
                added += 1
        except Exception:
            continue
    return added


def read_auth_summary(path):
    try:
        data = json.load(open(path, encoding='utf-8'))
        keys = ['account_id','email','expires_at','provider','plan']
        lines = [f'{k}: {data[k]}' for k in keys if k in data] or ['keys: ' + ', '.join(sorted(data.keys())[:12])]
        return '
'.join(lines)
    except Exception as e:
        return f'Unable to parse auth.json: {e}'


def verify(name=None):
    nm = name or read_current()
    if not nm:
        return []
    src = PROFILES / f'{nm}.json'
    out = []
    for t in codex_targets():
        ok = src.exists() and Path(t).exists() and open(src,'rb').read() == open(t,'rb').read()
        out.append((str(t), ok))
    return out
