-- The script under test is extracted from release.yaml by run.sh, so this can
-- never drift from what actually ships.
dofile("/w/identity.lua")

local fails = 0
local function check(name, record, want_app, want_job)
  local code, _, out = set_identity("kube.x", 123, record)
  local got_app, got_job = out["k8s_app"], out["k8s_job"]
  if got_app ~= want_app or got_job ~= want_job then
    print(string.format("FAIL %-34s app=%s job=%s (wanted app=%s job=%s)",
      name, tostring(got_app), tostring(got_job), tostring(want_app), tostring(want_job)))
    fails = fails + 1
  else
    print(string.format("ok   %-34s app=%s job=%s code=%d", name, got_app, got_job, code))
  end
end

local function k8s(ns, container, labels)
  return { kubernetes = { namespace_name = ns, container_name = container, labels = labels } }
end

-- Real shapes from this cluster.
check("helm chart (kubernetes.io/name)", k8s("monitoring","loki",{["app.kubernetes.io/name"]="loki",["app.kubernetes.io/instance"]="loki"}), "loki", "monitoring/loki")
check("sample app (commonLabels app)",   k8s("sample-apps","orders-api",{["app"]="orders-api"}), "orders-api", "sample-apps/orders-api")
check("kube-system (k8s-app)",           k8s("kube-system","coredns",{["k8s-app"]="kube-dns"}), "kube-dns", "kube-system/kube-dns")
check("instance only",                   k8s("monitoring","x",{["app.kubernetes.io/instance"]="grafana"}), "grafana", "monitoring/grafana")
check("no labels at all -> container",    k8s("default","sidecar",{}), "sidecar", "default/sidecar")
check("labels key missing entirely",      { kubernetes = { namespace_name="default", container_name="raw" } }, "raw", "default/raw")

-- Priority: name must win over app, which must win over k8s-app.
check("priority name > app > k8s-app",   k8s("ns","c",{["app.kubernetes.io/name"]="A",["app"]="B",["k8s-app"]="C"}), "A", "ns/A")
check("priority app > k8s-app",          k8s("ns","c",{["app"]="B",["k8s-app"]="C"}), "B", "ns/B")

-- pod-template-hash must never become the identity.
local r = k8s("sample-apps","orders-api",{["app"]="orders-api",["pod-template-hash"]="7d9f4c8b6"})
check("pod-template-hash ignored",       r, "orders-api", "sample-apps/orders-api")

-- A record with no kubernetes metadata must pass through UNTOUCHED (code 0).
local code, _, out = set_identity("x", 1, { log = "raw line" })
if code ~= 0 or out["k8s_app"] ~= nil then
  print("FAIL non-k8s record was modified"); fails = fails + 1
else
  print("ok   non-k8s record untouched         code=0")
end

-- The timestamp must survive: returning 1 instead of 2 would re-stamp every line.
local code2, ts2 = set_identity("x", 999, k8s("ns","c",{["app"]="a"}))
if code2 ~= 2 or ts2 ~= 999 then
  print(string.format("FAIL timestamp/return code: code=%d ts=%s", code2, tostring(ts2))); fails = fails + 1
else
  print("ok   original timestamp preserved     code=2")
end

print(fails == 0 and "\nALL PASS" or ("\n" .. fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
