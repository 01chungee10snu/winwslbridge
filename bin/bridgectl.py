#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
import base64
from pathlib import Path
from typing import Any

ROOT = Path(os.environ.get('OPENCLAW_BRIDGE_ROOT', '/home/brienz311/.openclaw/workspace/state/bridge'))
WINDOWS_SHARE = os.environ.get('OPENCLAW_BRIDGE_WINDOWS_SHARE')
STATE = ROOT / 'state'
TMP = ROOT / 'tmp'
LOGS = ROOT / 'logs'
REQ_DIR = Path(WINDOWS_SHARE) / 'state' / 'requests' if WINDOWS_SHARE else STATE / 'requests'
RES_DIR = Path(WINDOWS_SHARE) / 'state' / 'responses' if WINDOWS_SHARE else STATE / 'responses'


def ensure_dirs() -> None:
    for p in (STATE, TMP, LOGS, REQ_DIR, RES_DIR):
        p.mkdir(parents=True, exist_ok=True)


def wslify_result_paths(resp: dict[str, Any]) -> dict[str, Any]:
    result = resp.get('result')
    if isinstance(result, dict):
        path = result.get('path')
        if isinstance(path, str) and path.startswith('C:\\'):
            translated = '/mnt/c/' + path[3:].replace('\\', '/')
            result['wslPath'] = translated
    return resp


def make_request(action: str, args: dict[str, Any]) -> dict[str, Any]:
    return {
        'id': str(uuid.uuid4()),
        'action': action,
        'args': args,
        'client': 'bridgectl',
        'ts': time.time(),
    }


def send_fileq(payload: dict[str, Any], timeout_s: float) -> dict[str, Any]:
    req_path = REQ_DIR / f"{payload['id']}.json"
    res_path = RES_DIR / f"{payload['id']}.json"
    req_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8', newline='\n')
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if res_path.exists():
            data = json.loads(res_path.read_text(encoding='utf-8-sig'))
            return wslify_result_paths(data)
        time.sleep(0.1)
    return {
        'ok': False,
        'action': payload['action'],
        'error': f'timeout waiting for response in {res_path}',
        'durationMs': int(timeout_s * 1000),
        'requestId': payload['id'],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['health', 'capabilities', 'window-list', 'window-active', 'screen-capture', 'window-focus'])
    parser.add_argument('--title-contains', default='')
    parser.add_argument('--timeout', type=float, default=3.0)
    args = parser.parse_args()

    ensure_dirs()

    action_map = {
        'health': 'health',
        'capabilities': 'capabilities',
        'window-list': 'window.list',
        'window-active': 'window.active',
        'screen-capture': 'screen.capture',
        'window-focus': 'window.focus',
    }
    req_args = {}
    if args.action == 'window-focus':
        req_args['titleContains'] = args.title_contains
        req_args['titleContainsBase64'] = base64.b64encode(args.title_contains.encode('utf-8')).decode('ascii')
    payload = make_request(action_map[args.action], req_args)
    resp = send_fileq(payload, args.timeout)
    print(json.dumps(resp, ensure_ascii=False))
    return 0 if resp.get('ok') else 1


if __name__ == '__main__':
    sys.exit(main())
