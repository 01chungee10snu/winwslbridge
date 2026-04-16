#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from typing import Any


def wslify_result_paths(resp: dict[str, Any]) -> dict[str, Any]:
    result = resp.get('result')
    if isinstance(result, dict):
        path = result.get('path')
        if isinstance(path, str) and path.startswith('C:\\'):
            result['wslPath'] = '/mnt/c/' + path[3:].replace('\\', '/')
    return resp


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['health', 'capabilities', 'window-list', 'screen-capture'])
    parser.add_argument('--url', default='http://127.0.0.1:4765/')
    args = parser.parse_args()

    action_map = {
        'health': 'health',
        'capabilities': 'capabilities',
        'window-list': 'window.list',
        'screen-capture': 'screen.capture',
    }
    payload = json.dumps({'action': action_map[args.action], 'args': {}}).encode('utf-8')
    req = urllib.request.Request(args.url, data=payload, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode('utf-8'))
    data = wslify_result_paths(data)
    print(json.dumps(data, ensure_ascii=False))
    return 0 if data.get('ok') else 1


if __name__ == '__main__':
    sys.exit(main())
