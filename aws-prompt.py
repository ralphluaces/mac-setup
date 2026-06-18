#!/usr/bin/env python3
import os, re, sys
from datetime import datetime, timezone

profile = os.environ.get("AWS_PROFILE", "default")
region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")
creds = os.path.expanduser("~/.aws/credentials")

def get_expires(content, target_profile):
    sections = re.split(r"^\[(.+)\]$", content, flags=re.MULTILINE)
    for i in range(1, len(sections), 2):
        if sections[i] == target_profile:
            m = re.search(r"x_security_token_expires\s*=\s*(.+)", sections[i+1])
            if m:
                return m.group(1).strip()
    return None

def remaining(expires):
    try:
        secs = int((datetime.fromisoformat(expires) - datetime.now(timezone.utc)).total_seconds())
        return secs
    except:
        return -1

try:
    content = open(creds).read()
    expires = get_expires(content, profile)
    if not expires or remaining(expires) <= 0:
        expires = get_expires(content, "default")
except:
    expires = None

region_str = f":{region}" if region else ""

if not expires:
    print(f"aws:{profile}{region_str} ✗")
    sys.exit(0)

secs = remaining(expires)
if secs <= 0:
    print(f"aws:{profile}{region_str} ✗")
else:
    h, r = divmod(secs, 3600)
    m = r // 60
    t = f"{h}h{m:02d}m" if h else f"{m}m"
    print(f"aws:{profile}{region_str} ✓{t}")
