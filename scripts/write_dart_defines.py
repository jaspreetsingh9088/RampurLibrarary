#!/usr/bin/env python3
"""Write dart_defines.json for `flutter build --dart-define-from-file` from env vars.

CI maps GitHub secrets to these env vars. Missing values are simply omitted, in which
case the apps show a friendly "not configured" screen instead of crashing.
"""
import json
import os
import sys

KEYS = [
    "FIREBASE_API_KEY",
    "FIREBASE_PROJECT_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_STORAGE_BUCKET",
    "FIREBASE_AUTH_DOMAIN",
    "FIREBASE_MEASUREMENT_ID",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_ANDROID_APP_ID",
    "FIREBASE_IOS_APP_ID",
    "FIREBASE_IOS_CLIENT_ID",
    "FIREBASE_IOS_BUNDLE_ID",
    "FIREBASE_VAPID_KEY",
    "SITE_URL",
]

out = sys.argv[1] if len(sys.argv) > 1 else "dart_defines.json"
values = {k: os.environ[k] for k in KEYS if os.environ.get(k)}
with open(out, "w") as f:
    json.dump(values, f, indent=2)
missing = [k for k in KEYS if k not in values]
print(f"wrote {out} with {len(values)} keys" + (f" (missing: {', '.join(missing)})" if missing else ""))
