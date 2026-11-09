#!/usr/bin/env python3
"""Verify a staged Yapper installer against its appcast and source public key."""
import argparse
import base64
import hashlib
import pathlib
import plistlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("directory", type=pathlib.Path, help="Directory containing the DMG and appcast.xml")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
with (root / "app/Yapper/Support/Info.plist").open("rb") as source:
    info = plistlib.load(source)
feed = ET.parse(args.directory / "appcast.xml")
ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
item = feed.find("./channel/item")
if item is None:
    raise SystemExit("Appcast has no release item")
version = item.findtext("sparkle:shortVersionString", namespaces=ns)
assert version == info["CFBundleShortVersionString"], "Appcast version differs from app version"
assert item.findtext("sparkle:version", namespaces=ns) == info["CFBundleVersion"], "Build number mismatch"
enclosure = item.find("enclosure")
assert enclosure is not None, "Appcast has no download"
filename = f"Yapper-{version}.dmg"
assert enclosure.attrib["url"] == f"https://yapper.party/downloads/{filename}", "Unexpected update URL"
downloads = args.directory / "downloads" if (args.directory / "downloads").is_dir() else args.directory
installer = downloads / filename
assert installer.is_file(), "Versioned installer is missing"
assert installer.stat().st_size == int(enclosure.attrib["length"]), "Appcast file size mismatch"
with installer.open("rb") as source:
    source.seek(-512, 2)
    assert source.read(4) == b"koly", "Installer is not a UDIF disk image"
checksum = hashlib.sha256(installer.read_bytes()).hexdigest()
checksum_file = downloads / f"{filename}.sha256"
assert checksum_file.read_text().split()[0] == checksum, "SHA-256 mismatch"
latest = downloads / "Yapper-latest.dmg"
if latest.exists():
    assert hashlib.sha256(latest.read_bytes()).hexdigest() == checksum, "Latest installer differs from versioned installer"
# Ed25519 SubjectPublicKeyInfo header followed by the app's 32-byte Sparkle key.
public_key = bytes.fromhex("302a300506032b6570032100") + base64.b64decode(info["SUPublicEDKey"], validate=True)
signature = base64.b64decode(enclosure.attrib[f"{{{ns['sparkle']}}}edSignature"], validate=True)
with tempfile.TemporaryDirectory(prefix="yapper-verify-") as directory:
    key_path = pathlib.Path(directory) / "public.der"
    sig_path = pathlib.Path(directory) / "signature"
    key_path.write_bytes(public_key)
    sig_path.write_bytes(signature)
    subprocess.run(["openssl", "pkeyutl", "-verify", "-pubin", "-keyform", "DER", "-inkey", str(key_path), "-rawin", "-in", str(installer), "-sigfile", str(sig_path)], check=True)
print(f"Verified Yapper {version} build {info['CFBundleVersion']}: {installer.stat().st_size:,} bytes, signed update, SHA-256 {checksum}")
