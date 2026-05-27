#!/usr/bin/env python3
"""GitHub Actions: ExportOptions.plist for flutter build ipa (ad-hoc, manual signing)."""

import os
import plistlib
from pathlib import Path

PROFILE = os.environ.get("IOS_PROVISIONING_PROFILE_NAME", "").strip()
BUNDLE_ID = os.environ.get("IOS_BUNDLE_ID", "com.example.anncGo").strip()
OUTPUT = Path(__file__).resolve().parent / "ExportOptions.plist"


def main() -> None:
    if not PROFILE:
        raise SystemExit(
            "IOS_PROVISIONING_PROFILE_NAME is empty. "
            "Set it to match the provisioning profile name in Xcode/Apple Developer."
        )
    data = {
        "method": os.environ.get("IOS_EXPORT_METHOD", "ad-hoc"),
        "signingStyle": "manual",
        "compileBitcode": False,
        "provisioningProfiles": {BUNDLE_ID: PROFILE},
    }
    OUTPUT.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML))


if __name__ == "__main__":
    main()
