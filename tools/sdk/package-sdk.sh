#!/bin/bash
set -euo pipefail
sdk_tool_root="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$sdk_tool_root/sdk.py" package "$@"
