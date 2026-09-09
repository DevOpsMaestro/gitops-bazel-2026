import sys, json
data = json.load(sys.stdin)
for ep in data:
    s     = ep.get("Status", {})
    db    = s.get("dbSize", 0)
    inuse = s.get("dbSizeInUse", 0)
    quota = s.get("dbSizeAlarmThreshold", 2 * 1024 * 1024 * 1024)
    frag  = (db - inuse) / db * 100 if db else 0
    pct   = db / quota * 100 if quota else 0
    print("  dbSize        : %d MB  (%.1f%% of %d MB quota)" % (db >> 20, pct, quota >> 20))
    print("  inUse         : %d MB" % (inuse >> 20))
    print("  fragmentation : %.1f%%" % frag)
    if frag > 30:
        print("  WARNING: fragmentation exceeds 30% -- run: bazel run //:etcd-defrag")
    else:
        print("  OK: fragmentation is within acceptable range")
