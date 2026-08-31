#!/usr/bin/env bash
# Unit-tests the Lua that decides the `app` and `job` label of every log line in
# the cluster. It extracts the script from release.yaml rather than keeping a
# second copy, so a change to the shipped config is what gets tested.
#
#   ./apps/base/systems/fluentbit/test/run.sh
#
# Needs docker (for a Lua interpreter) and python3.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python3 -c "
import yaml
d = yaml.safe_load(open('$here/../release.yaml'))
open('$work/identity.lua', 'w').write(d['spec']['values']['luaScripts']['identity.lua'])
"
cp "$here/identity_spec.lua" "$work/spec.lua"
docker run --rm -v "$work":/w -w /w nickblah/lua:5.4 lua spec.lua
