"""Convert MAJOR.MINOR.PATCH to a monotonically increasing Android versionCode."""
import re
import sys

if len(sys.argv) != 2 or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", sys.argv[1]):
    sys.exit("Expected a version like 1.1.0")

major, minor, patch = map(int, sys.argv[1].split("."))
if major > 1999 or minor > 999 or patch > 999:
    sys.exit("Version fields out of range")
print(major * 1000000 + minor * 1000 + patch)
