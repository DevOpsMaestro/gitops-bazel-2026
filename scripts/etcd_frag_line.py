import sys, json
data = json.load(sys.stdin)
for ep in data:
    s     = ep.get("Status", {})
    db    = s.get("dbSize", 0)
    inuse = s.get("dbSizeInUse", 0)
    frag  = (db - inuse) / db * 100 if db else 0
    print("  dbSize=%dMB  inUse=%dMB  fragmentation=%.1f%%" % (db >> 20, inuse >> 20, frag))
