#!/usr/bin/env bash
# Fails when a chart's default settings drift from the Kustomize config they mirror.
#
# The charts default to the reference deployment's sample settings, which live in
# components/<component>/config. Keys the chart derives itself (connection strings, Server.Host)
# are left out of the chart defaults and so out of the comparison.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

helm show values charts/snapcd-server | python3 -c '
import json, sys, yaml

values = yaml.safe_load(sys.stdin)
expected = json.load(open("components/server/config/appsettings.json"))
del expected["ConnectionString"]
del expected["Caching"]["ConnectionString"]
del expected["ServiceBus"]["TransportOptions"]["SqlServer"]["ConnectionString"]
del expected["Server"]["Host"]
if not expected["Server"]:
    del expected["Server"]

env = dict(line.split("=", 1) for line in open("components/server/config/sql-secret.env").read().splitlines() if "=" in line)

failed = False
if values["config"]["appsettings"] != expected:
    print("charts/snapcd-server config.appsettings differs from components/server/config/appsettings.json", file=sys.stderr)
    failed = True
if values["sqlserver"]["auth"]["saPassword"] != env["SA_PASSWORD"]:
    print("charts/snapcd-server sqlserver.auth.saPassword differs from components/server/config/sql-secret.env", file=sys.stderr)
    failed = True
sys.exit(1 if failed else 0)
'

helm show values charts/snapcd-runner | python3 -c '
import json, os, sys, yaml

values = yaml.safe_load(sys.stdin)
config = "components/runner/config"
env = dict(line.split("=", 1) for line in open(f"{config}/runner-secret.env").read().splitlines() if "=" in line)
hooks = {name: open(f"{config}/preapproved-hooks/{name}").read() for name in os.listdir(f"{config}/preapproved-hooks")}

checks = [
    (values["config"]["appsettings"] == json.load(open(f"{config}/appsettings.json")), "config.appsettings", "appsettings.json"),
    (values["credentials"]["clientSecret"] == env["Runner__Credentials__ClientSecret"], "credentials.clientSecret", "runner-secret.env"),
    (values["ssh"]["knownHosts"] == open(f"{config}/known_hosts").read(), "ssh.knownHosts", "known_hosts"),
    (values["preapprovedHooks"]["hooks"] == hooks, "preapprovedHooks.hooks", "preapproved-hooks/"),
]
failed = False
for ok, value, source in checks:
    if not ok:
        print(f"charts/snapcd-runner {value} differs from {config}/{source}", file=sys.stderr)
        failed = True
sys.exit(1 if failed else 0)
'
