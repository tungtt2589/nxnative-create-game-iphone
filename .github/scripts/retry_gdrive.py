import json, subprocess, os, sys

listing = os.path.expanduser("~/gdrive_listing.json")
base = os.path.expanduser("~/gdrive_raw")

try:
    files = json.load(open(listing))
    for item in files:
        fid = item.get("id", "")
        path = item.get("path", "") or item.get("name", "")
        if not path or not fid:
            continue
        local = os.path.join(base, path)
        if not os.path.exists(local):
            print(f"Retrying large file: {local}")
            os.makedirs(os.path.dirname(local), exist_ok=True)
            subprocess.run(["gdown", "--fuzzy", fid, "-O", local], check=False)
except Exception as e:
    print(f"Retry skipped: {e}", file=sys.stderr)
