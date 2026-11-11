#!/usr/bin/env python3
"""Print the NVR of kwin in Fedora's stable repos (Koji tag fN-updates, inheriting fN).

mdapi lags behind and can report a testing build, so ask Koji directly.
Usage: latest-stable.py 45
"""

import sys
import xmlrpc.client

fedora = sys.argv[1]
koji = xmlrpc.client.ServerProxy("https://koji.fedoraproject.org/kojihub", allow_none=True)
builds = koji.listTagged(f"f{fedora}-updates",
                         {"package": "kwin", "latest": True, "inherit": True, "__starstar": True})
if len(builds) != 1:
    sys.exit(f"expected one kwin build in f{fedora}-updates, got {[b['nvr'] for b in builds]}")
print(builds[0]["nvr"])
