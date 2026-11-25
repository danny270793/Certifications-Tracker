#!/usr/bin/env python3
"""Uploads certifications (certifications.json) and courses (courses.json), with their files, to Supabase.

It talks to the Supabase REST and Storage APIs as *you*: it signs in with your email and
password (the same account the app uses), so row level security applies and each row and
PDF lands in your own account. No service key is used.

    export CERTS_EMAIL=you@example.com
    export CERTS_PASSWORD=...            # or leave it unset to be asked
    python3 scripts/upload_certifications.py \\
        --pdf-dir /path/to/Certifications --courses-dir /path/to/Courses [--dry-run]

Pass only the folder(s) you want to upload.

The Supabase URL and anon key come from CertificationsTracker/Resources/CertsConfig.plist.
Rows get a stable id derived from your user id and the file name, so running the script
again updates the same rows instead of creating duplicates.
"""
import argparse
import getpass
import json
import os
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import urllib.parse
import uuid

here = pathlib.Path(__file__).resolve().parent
default_config = here.parent / "CertificationsTracker" / "Resources" / "CertsConfig.plist"
BUCKET = "cert-pdfs"
TABLE = "cert_certifications"
COURSES_TABLE = "cert_courses"


def call(method, url, headers, body=None):
    """Sends the request with curl, which uses the macOS system trust store (so corporate
    TLS-inspection CAs trusted in Keychain work). Headers go through a private temp file so
    tokens never show up in the process list."""
    with tempfile.NamedTemporaryFile("w", suffix=".hdr") as header_file:
        os.chmod(header_file.name, 0o600)
        header_file.write("".join(f"{k}: {v}\n" for k, v in headers.items()))
        header_file.flush()
        command = [
            "curl", "--silent", "--show-error", "--location", "--max-time", "120",
            "--request", method, "--header", f"@{header_file.name}",
            "--write-out", "\n%{http_code}", "--data-binary", "@-", url,
        ]
        result = subprocess.run(command, input=body or b"", capture_output=True)
    if result.returncode != 0:
        sys.exit(f"{method} {url} failed: {result.stderr.decode(errors='replace').strip()}")
    payload, _, status = result.stdout.rpartition(b"\n")
    if not status.strip().startswith(b"2"):
        sys.exit(f"{method} {url} failed: HTTP {status.decode().strip()} {payload.decode(errors='replace')[:400]}")
    return json.loads(payload) if payload.strip() else None


def file_kind(data):
    """Returns (extension, content type) from the first bytes: some file names have odd or no extension."""
    if data.startswith(b"\xff\xd8"):
        return "jpg", "image/jpeg"
    if data.startswith(b"\x89PNG"):
        return "png", "image/png"
    return "pdf", "application/pdf"


def upload_file(base, auth, path, data, content_type):
    call(
        "POST", f"{base}/storage/v1/object/{BUCKET}/{urllib.parse.quote(path)}",
        {**auth, "Content-Type": content_type, "x-upsert": "true"}, data,
    )


def upsert_row(base, auth, table, row):
    call(
        "POST", f"{base}/rest/v1/{table}?on_conflict=id",
        {**auth, "Content-Type": "application/json", "Prefer": "resolution=merge-duplicates,return=minimal"},
        json.dumps(row).encode(),
    )


def check_files(items, folder, label):
    if not folder.is_dir():
        sys.exit(f"The {label} folder does not exist: {folder.resolve()}\n(paths are relative to where you run the script)")
    missing = [i["file"] for i in items if not (folder / i["file"]).is_file()]
    if missing:
        sys.exit(f"Missing {label} files in {folder}:\n  " + "\n  ".join(missing))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pdf-dir", type=pathlib.Path, help="folder with the certification PDFs")
    parser.add_argument("--courses-dir", type=pathlib.Path, help="folder with the course certificates")
    parser.add_argument("--config", type=pathlib.Path, default=default_config)
    parser.add_argument("--manifest", type=pathlib.Path, default=here / "certifications.json")
    parser.add_argument("--courses-manifest", type=pathlib.Path, default=here / "courses.json")
    parser.add_argument("--dry-run", action="store_true", help="check the files and the sign-in, upload nothing")
    args = parser.parse_args()
    if not args.pdf_dir and not args.courses_dir:
        parser.error("pass --pdf-dir and/or --courses-dir")

    config = plistlib.loads(args.config.read_bytes())
    base, anon = config["SUPABASE_URL"].rstrip("/"), config["SUPABASE_ANON_KEY"]
    if "xxxx" in base:
        sys.exit(f"Fill in {args.config} first.")
    certs = json.loads(args.manifest.read_text(encoding="utf-8")) if args.pdf_dir else []
    courses = json.loads(args.courses_manifest.read_text(encoding="utf-8")) if args.courses_dir else []
    if certs:
        check_files(certs, args.pdf_dir, "certification")
    if courses:
        check_files(courses, args.courses_dir, "course")

    email = os.environ.get("CERTS_EMAIL") or input("Email: ")
    password = os.environ.get("CERTS_PASSWORD") or getpass.getpass("Password: ")
    session = call(
        "POST", f"{base}/auth/v1/token?grant_type=password",
        {"apikey": anon, "Content-Type": "application/json"},
        json.dumps({"email": email, "password": password}).encode(),
    )
    token, user = session["access_token"], session["user"]["id"]
    auth = {"apikey": anon, "Authorization": f"Bearer {token}"}
    print(f"Signed in. {len(certs)} certifications and {len(courses)} courses to upload.")
    if args.dry_run:
        return

    for n, item in enumerate(certs, 1):
        cert_id = str(uuid.uuid5(uuid.UUID(user), item["file"]))
        path = f"{user}/{cert_id}.pdf"
        upload_file(base, auth, path, (args.pdf_dir / item["file"]).read_bytes(), "application/pdf")
        upsert_row(base, auth, TABLE, {
            "id": cert_id,
            "userId": user,
            "name": item["name"],
            "provider": item["provider"],
            "earnDate": item["earnDate"],
            "expirationDate": item.get("expirationDate"),
            "verificationUrl": item.get("verificationUrl"),
            "tags": item.get("tags", []),
            "pdfPath": path,
            "price": item.get("price", 0),
            "deletedAt": None,
        })
        print(f"[certification {n}/{len(certs)}] {item['name']}")

    for n, item in enumerate(courses, 1):
        course_id = str(uuid.uuid5(uuid.UUID(user), "course:" + item["file"]))
        data = (args.courses_dir / item["file"]).read_bytes()
        ext, content_type = file_kind(data)
        path = f"{user}/courses/{course_id}.{ext}"
        upload_file(base, auth, path, data, content_type)
        upsert_row(base, auth, COURSES_TABLE, {
            "id": course_id,
            "userId": user,
            "name": item["name"],
            "provider": item["provider"],
            "price": item.get("price", 0),
            "earnDate": item["earnDate"],
            "hours": item.get("hours", 0),
            "tags": item.get("tags", []),
            "filePath": path,
            "deletedAt": None,
        })
        print(f"[course {n}/{len(courses)}] {item['name']}")
    print("Done.")


if __name__ == "__main__":
    main()
