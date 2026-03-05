"""Line-based peers.conf writer that preserves comments and formatting.

Uses parse_peers_conf() from api_mesh for reading (no duplication).
Writing is line-based to preserve INI comments (configparser.write destroys them).
"""

import fcntl
import os
import re
import shutil
from datetime import datetime
from pathlib import Path

from api_mesh import parse_peers_conf

_SECTION_RE = re.compile(r'^\[([^\]]+)\]')
_KV_RE = re.compile(r'^([a-z_]+)\s*=\s*(.*)')
_KNOWN_FIELDS = [
    'ssh_alias', 'user', 'os', 'tailscale_ip', 'dns_name',
    'capabilities', 'role', 'status', 'mac_address',
    'default_engine', 'default_model',
]
_VALID_ENGINES = {'claude', 'copilot', 'opencode', 'ollama'}
_MAC_RE = re.compile(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
_IP_RE = re.compile(r'^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
_NAME_RE = re.compile(r'^[a-zA-Z0-9_.-]+$')


class PeersWriter:
    def __init__(self, conf_path: str | Path):
        self.path = Path(conf_path)

    def list_peers(self) -> list[dict]:
        return parse_peers_conf()

    def _read_lines(self) -> list[str]:
        if not self.path.exists():
            return []
        return self.path.read_text().splitlines(keepends=True)

    def _find_section(self, lines: list[str], name: str) -> tuple[int, int]:
        """Return (start, end) line indices for section [name]. end is exclusive."""
        start = -1
        for i, line in enumerate(lines):
            m = _SECTION_RE.match(line.strip())
            if m:
                if m.group(1).lower() == name.lower():
                    start = i
                elif start >= 0:
                    return start, i
        if start >= 0:
            return start, len(lines)
        return -1, -1

    def _backup(self):
        """Backup peers.conf with timestamp before any write (C-02)."""
        if self.path.exists():
            ts = datetime.now().strftime('%Y%m%d-%H%M%S')
            shutil.copy2(str(self.path), f'{self.path}.bak.{ts}')

    def _atomic_write(self, lines: list[str]):
        """Write via .tmp + os.rename for atomicity (C-10)."""
        tmp = Path(f'{self.path}.tmp')
        tmp.write_text(''.join(lines))
        os.rename(str(tmp), str(self.path))

    def _locked_write(self, write_fn):
        """Execute write_fn under fcntl.flock (C-06)."""
        lock_path = Path(f'{self.path}.lock')
        lock_path.touch(exist_ok=True)
        fd = open(str(lock_path), 'r')
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            self._backup()
            write_fn()
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            fd.close()

    def _format_section(self, name: str, data: dict) -> list[str]:
        """Format a peer section as lines."""
        lines = [f'[{name}]\n']
        for field in _KNOWN_FIELDS:
            if field in data and data[field]:
                lines.append(f'{field}={data[field]}\n')
        return lines

    def _validate(self, data: dict, is_update: bool = False):
        """Validate peer data. Raises ValueError on invalid input."""
        if not is_update:
            for req in ('ssh_alias', 'user', 'os', 'role'):
                if not data.get(req):
                    raise ValueError(f'Missing required field: {req}')
        if data.get('os') and data['os'] not in ('macos', 'linux'):
            raise ValueError(f"Invalid os: {data['os']} (must be macos|linux)")
        if data.get('role') and data['role'] not in ('coordinator', 'worker', 'hybrid'):
            raise ValueError(f"Invalid role: {data['role']}")
        if data.get('mac_address') and not _MAC_RE.match(data['mac_address']):
            raise ValueError(f"Invalid MAC format: {data['mac_address']}")
        if data.get('tailscale_ip') and not _IP_RE.match(data['tailscale_ip']):
            raise ValueError(f"Invalid Tailscale IP: {data['tailscale_ip']}")
        if data.get('default_engine') and data['default_engine'] not in _VALID_ENGINES:
            raise ValueError(f"Invalid engine: {data['default_engine']}")

    def _peer_exists(self, name: str) -> bool:
        """Case-insensitive peer name existence check (C-09)."""
        return any(p['peer_name'].lower() == name.lower() for p in self.list_peers())

    def add_peer(self, data: dict) -> dict:
        """Add a new peer section. Returns {'ok': True, 'peer_name': name}."""
        name = data.get('peer_name', '').strip()
        if not name or not _NAME_RE.match(name):
            raise ValueError(f'Invalid peer name: {name}')
        if self._peer_exists(name):
            raise ValueError(f'Duplicate peer name (case-insensitive): {name}')
        self._validate(data)

        def do_write():
            lines = self._read_lines()
            if lines and not lines[-1].endswith('\n'):
                lines[-1] += '\n'
            if lines and lines[-1].strip():
                lines.append('\n')
            lines.extend(self._format_section(name, data))
            self._atomic_write(lines)

        self._locked_write(do_write)
        return {'ok': True, 'peer_name': name}

    def update_peer(self, name: str, data: dict) -> dict:
        """Update an existing peer's fields (preserves unmentioned fields)."""
        self._validate(data, is_update=True)

        def do_write():
            lines = self._read_lines()
            start, end = self._find_section(lines, name)
            if start < 0:
                raise ValueError(f'Peer not found: {name}')
            existing = {}
            for line in lines[start + 1:end]:
                m = _KV_RE.match(line.strip())
                if m:
                    existing[m.group(1)] = m.group(2)
            existing.update({k: v for k, v in data.items() if k != 'peer_name' and v is not None})
            new_section = self._format_section(name, existing)
            trail = '\n' if end < len(lines) else ''
            lines[start:end] = new_section + ([trail] if trail else [])
            self._atomic_write(lines)

        self._locked_write(do_write)
        return {'ok': True, 'peer_name': name}

    def delete_peer(self, name: str, mode: str = 'soft') -> dict:
        """Delete peer. soft=set status=inactive, hard=remove section entirely."""
        if mode not in ('soft', 'hard'):
            raise ValueError(f'Invalid delete mode: {mode}')
        if mode == 'soft':
            return self.update_peer(name, {'status': 'inactive'})

        def do_write():
            lines = self._read_lines()
            start, end = self._find_section(lines, name)
            if start < 0:
                raise ValueError(f'Peer not found: {name}')
            while end < len(lines) and not lines[end].strip():
                end += 1
            del lines[start:end]
            self._atomic_write(lines)

        self._locked_write(do_write)
        return {'ok': True, 'peer_name': name, 'mode': 'hard'}
