#!/usr/bin/env bash
# ==============================================================================
# vdetect.sh — CMS & Web Application Version Detector CLI (v2.0.0)
# Modernized clean-room implementation inspired by legacy vdetect (Python 2.7).
# Copyright (c) 2026 Percio Castelo — Apache-2.0 License
# ==============================================================================
set -euo pipefail

VERSION="2.0.0"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required (3.6+)." >&2
    exit 1
fi

read -r -d '' PY_SCRIPT << 'EOF' || true
import argparse
import csv
import glob
import io
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

VERSION = "2.0.0"

SKIP_DIRS = {
    "virtfs", "mail", "cache", "images", "image", "img", "tmp",
    "node_modules", ".git", ".svn", "vendor", "__pycache__",
}

BUILTIN_SIGNATURES = [
    {
        "name": "WordPress",
        "min_overlap": 0.5,
        "files": ["wp-includes/version.php", "wp-login.php", "wp-config.php"],
        "version_checks": [
            {"file": "wp-includes/version.php", "regex": r"\$wp_version\s*=\s*['\"]([^'\"]+)['\"]"},
        ],
        "min_safe": "6.6.0",
        "upgrade_url": "https://wordpress.org/download/",
    },
    {
        "name": "Joomla",
        "min_overlap": 0.5,
        "files": ["administrator/manifests/files/joomla.xml", "libraries/src/Version.php", "configuration.php"],
        "version_checks": [
            {"file": "administrator/manifests/files/joomla.xml", "regex": r"<version>([^<]+)</version>"},
            {"file": "libraries/src/Version.php", "regex": r"MAJOR_VERSION\s*=\s*(\d+).*?MINOR_VERSION\s*=\s*(\d+).*?PATCH_VERSION\s*=\s*(\d+)"},
        ],
        "min_safe": "5.1.0",
        "upgrade_url": "https://downloads.joomla.org/",
    },
    {
        "name": "Drupal",
        "min_overlap": 0.5,
        "files": ["core/lib/Drupal.php", "core/CHANGELOG.txt", "sites/default/settings.php"],
        "version_checks": [
            {"file": "core/lib/Drupal.php", "regex": r"const\s+VERSION\s*=\s*['\"]([^'\"]+)['\"]"},
        ],
        "min_safe": "10.3.0",
        "upgrade_url": "https://www.drupal.org/download",
    },
    {
        "name": "Laravel",
        "min_overlap": 0.5,
        "files": ["artisan", "bootstrap/app.php", "composer.json"],
        "version_checks": [
            {"file": "vendor/laravel/framework/src/Illuminate/Foundation/Application.php", "regex": r"const\s+VERSION\s*=\s*['\"]([^'\"]+)['\"]"},
            {"file": "composer.json", "regex": r"\"laravel/framework\"\s*:\s*\"[^\d]*([0-9]+(?:\.[0-9]+){0,2})"},
        ],
        "min_safe": "11.0.0",
        "upgrade_url": "https://laravel.com/docs/upgrade",
    },
    {
        "name": "phpMyAdmin",
        "min_overlap": 0.5,
        "files": ["libraries/classes/Version.php", "config.inc.php", "ChangeLog"],
        "version_checks": [
            {"file": "libraries/classes/Version.php", "regex": r"const\s+VERSION\s*=\s*['\"]([^'\"]+)['\"]"},
            {"file": "README", "regex": r"Version\s+([0-9]+\.[0-9]+\.[0-9]+)"},
        ],
        "min_safe": "5.2.1",
        "upgrade_url": "https://www.phpmyadmin.net/downloads/",
    },
    {
        "name": "Roundcube",
        "min_overlap": 0.5,
        "files": ["program/include/iniset.php", "config/config.inc.php", "index.php"],
        "version_checks": [
            {"file": "program/include/iniset.php", "regex": r"RCMAIL_VERSION['\"]\s*,\s*['\"]([^'\"]+)['\"]"},
        ],
        "min_safe": "1.6.8",
        "upgrade_url": "https://roundcube.net/download/",
    },
    {
        "name": "PrestaShop",
        "min_overlap": 0.5,
        "files": ["config/settings.inc.php", "app/AppKernel.php", "classes/PrestaShopAutoload.php"],
        "version_checks": [
            {"file": "config/settings.inc.php", "regex": r"_PS_VERSION_['\"]\s*,\s*['\"]([^'\"]+)['\"]"},
            {"file": "app/AppKernel.php", "regex": r"const\s+VERSION\s*=\s*['\"]([^'\"]+)['\"]"},
        ],
        "min_safe": "8.1.7",
        "upgrade_url": "https://www.prestashop.com/en/download",
    },
    {
        "name": "OpenCart",
        "min_overlap": 0.5,
        "files": ["system/startup.php", "admin/config.php", "index.php"],
        "version_checks": [
            {"file": "index.php", "regex": r"define\s*\(\s*['\"]VERSION['\"]\s*,\s*['\"]([^'\"]+)['\"]"},
            {"file": "admin/index.php", "regex": r"define\s*\(\s*['\"]VERSION['\"]\s*,\s*['\"]([^'\"]+)['\"]"},
        ],
        "min_safe": "4.0.2",
        "upgrade_url": "https://www.opencart.com/index.php?route=cms/download",
    },
    {
        "name": "Next.js",
        "min_overlap": 1.0,
        "files": ["package.json"],
        "require_regex": {"file": "package.json", "regex": r"\"next\"\s*:"},
        "version_checks": [
            {"file": "package.json", "regex": r"\"next\"\s*:\s*\"[^\d]*([0-9]+(?:\.[0-9]+){1,2})"},
        ],
        "min_safe": "14.2.0",
        "upgrade_url": "https://nextjs.org/docs/app/building-your-application/upgrading",
    },
]


class Colors:
    def __init__(self, enabled=True):
        self.RESET = "\033[0m" if enabled else ""
        self.BOLD = "\033[1m" if enabled else ""
        self.CYAN = "\033[36m" if enabled else ""
        self.GREEN = "\033[32m" if enabled else ""
        self.YELLOW = "\033[33m" if enabled else ""
        self.RED = "\033[31m" if enabled else ""
        self.DIM = "\033[2m" if enabled else ""


def parse_version_tuple(v):
    if not v:
        return ()
    nums = re.findall(r"\d+", v)
    return tuple(int(x) for x in nums[:4])


def compare_versions(detected, min_safe):
    if not detected:
        return "UNKNOWN"
    if not min_safe:
        return "DETECTED"
    vt = parse_version_tuple(detected)
    mt = parse_version_tuple(min_safe)
    if not vt:
        return "UNKNOWN"
    max_len = max(len(vt), len(mt))
    vt = vt + (0,) * (max_len - len(vt))
    mt = mt + (0,) * (max_len - len(mt))
    return "CURRENT" if vt >= mt else "OUTDATED"


def load_external_signatures(path):
    sigs = []
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Signatures file not found: {path}")
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    if raw.lstrip().startswith("{") or raw.lstrip().startswith("["):
        data = json.loads(raw)
        return data if isinstance(data, list) else data.get("signatures", [])
    root = ET.fromstring(raw)
    for node in root.findall(".//signature"):
        name = (node.findtext("applicationName") or "").strip()
        min_ov = float(node.findtext("minOverlap") or "1.0")
        files = [f.text.strip() for f in node.findall("./fileSignatures/filename") if f.text]
        vchecks = []
        for vs in node.findall("./versionSignatures/versionSignature"):
            fn = (vs.findtext("filename") or "").strip()
            rx = (vs.findtext("regexPattern") or "").strip()
            if fn and rx:
                vchecks.append({"file": fn, "regex": rx})
        acceptable = [a.text.strip() for a in node.findall("./versions/acceptableVersion") if a.text]
        min_safe = acceptable[-1] if acceptable else ""
        if name and files:
            sigs.append({
                "name": name,
                "min_overlap": min_ov,
                "files": files,
                "version_checks": vchecks,
                "min_safe": min_safe,
                "upgrade_url": (node.findtext("upgradeUrl") or "").strip(),
            })
    return sigs


def get_cpanel_docroots_for_user(username, cpanel_root="/var/cpanel"):
    docroots = []
    ud_dir = os.path.join(cpanel_root, "userdata", username)
    if os.path.isdir(ud_dir):
        for fname in os.listdir(ud_dir):
            if fname in ("main", "cache") or fname.endswith("_SSL") or fname.endswith(".cache"):
                continue
            fpath = os.path.join(ud_dir, fname)
            if not os.path.isfile(fpath):
                continue
            try:
                with open(fpath, "r", encoding="utf-8", errors="replace") as fh:
                    for line in fh:
                        if line.strip().startswith("documentroot:"):
                            dr = line.split(":", 1)[1].strip().strip("'\"")
                            if dr and os.path.isdir(dr):
                                docroots.append(dr)
            except OSError:
                pass
    if not docroots:
        try:
            pw = pwd.getpwnam(username)
            pub = os.path.join(pw.pw_dir, "public_html")
            if os.path.isdir(pub):
                docroots.append(pub)
            elif os.path.isdir(pw.pw_dir):
                docroots.append(pw.pw_dir)
        except KeyError:
            pass
    return docroots


def discover_all_docroots(etc_root="/etc", cpanel_root="/var/cpanel"):
    roots = []
    ud_base = os.path.join(cpanel_root, "userdata")
    if os.path.isdir(ud_base):
        for user in os.listdir(ud_base):
            if user != "nobody":
                roots.extend(get_cpanel_docroots_for_user(user, cpanel_root))

    for conf_glob in (
        os.path.join(etc_root, "apache2", "sites-enabled", "*.conf"),
        os.path.join(etc_root, "httpd", "conf.d", "*.conf"),
        os.path.join(etc_root, "nginx", "sites-enabled", "*"),
    ):
        for conf in glob.glob(conf_glob):
            if not os.path.isfile(conf):
                continue
            try:
                with open(conf, "r", encoding="utf-8", errors="replace") as fh:
                    for line in fh:
                        m = re.match(r"^\s*(?:DocumentRoot|root)\s+([^;]+)", line)
                        if m:
                            dr = m.group(1).strip().strip("'\"")
                            if os.path.isdir(dr):
                                roots.append(dr)
            except OSError:
                pass
    return sorted(set(roots))


def get_reseller_users(reseller, etc_root="/etc"):
    users = []
    fpath = os.path.join(etc_root, "trueuserowners")
    if not os.path.isfile(fpath):
        return users
    try:
        with open(fpath, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if ":" in line:
                    u, owner = line.split(":", 1)
                    if owner.strip() == reseller:
                        users.append(u.strip())
    except OSError:
        pass
    return users


def match_signature(root_dir, sig):
    matched_files = 0
    for rel in sig["files"]:
        if os.path.exists(os.path.join(root_dir, rel)):
            matched_files += 1
    if not sig["files"]:
        return None
    overlap = matched_files / float(len(sig["files"]))
    if overlap < sig.get("min_overlap", 1.0):
        return None

    req = sig.get("require_regex")
    if req:
        req_path = os.path.join(root_dir, req["file"])
        if not os.path.isfile(req_path):
            return None
        try:
            with open(req_path, "r", encoding="utf-8", errors="replace") as fh:
                if not re.search(req["regex"], fh.read(), re.MULTILINE | re.DOTALL):
                    return None
        except OSError:
            return None

    detected_version = ""
    for vc in sig.get("version_checks", []):
        vfile = os.path.join(root_dir, vc["file"])
        if not os.path.isfile(vfile):
            continue
        try:
            with open(vfile, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read(131072)
            m = re.search(vc["regex"], content, re.MULTILINE | re.DOTALL)
            if m:
                detected_version = ".".join(g for g in m.groups() if g is not None)
                break
        except OSError:
            continue

    min_safe = sig.get("min_safe", "")
    status = compare_versions(detected_version, min_safe)
    return {
        "application": sig["name"],
        "version": detected_version or "UNKNOWN",
        "min_safe": min_safe or "-",
        "status": status,
        "path": root_dir,
        "overlap": round(overlap, 2),
        "upgrade_url": sig.get("upgrade_url", ""),
    }


def scan_paths(paths, maxdepth, signatures, exclude_dirs):
    findings = []
    seen = set()
    for base in paths:
        base = os.path.abspath(base)
        if not os.path.isdir(base):
            continue
        base_depth = base.rstrip(os.sep).count(os.sep)
        for root, dirs, _files in os.walk(base, followlinks=False):
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            cur_depth = root.rstrip(os.sep).count(os.sep) - base_depth
            if maxdepth >= 0 and cur_depth > maxdepth:
                dirs[:] = []
                continue
            if maxdepth >= 0 and cur_depth == maxdepth:
                dirs[:] = []

            for sig in signatures:
                res = match_signature(root, sig)
                if res:
                    key = (res["application"], res["path"])
                    if key not in seen:
                        seen.add(key)
                        findings.append(res)
    return findings


def render_table(findings, c):
    print(f"{c.BOLD}{c.CYAN}=== vdetect.sh v{VERSION} | CMS & Web App Version Report ==={c.RESET}")
    if not findings:
        print(f"  {c.DIM}No matching applications detected.{c.RESET}")
        return
    header = f"{'STATUS':<10} {'APPLICATION':<14} {'VERSION':<12} {'MIN_SAFE':<10} PATH"
    print(f"{c.BOLD}{header}{c.RESET}")
    print("-" * 80)
    for f in findings:
        st = f["status"]
        if st == "CURRENT":
            st_col = f"{c.GREEN}{st:<10}{c.RESET}"
        elif st == "OUTDATED":
            st_col = f"{c.RED}{st:<10}{c.RESET}"
        else:
            st_col = f"{c.YELLOW}{st:<10}{c.RESET}"
        print(f"{st_col} {f['application']:<14} {f['version']:<12} {f['min_safe']:<10} {f['path']}")


def render_csv(findings):
    buf = io.StringIO()
    writer = csv.writer(buf)
    fields = ["status", "application", "version", "min_safe", "path", "overlap", "upgrade_url"]
    writer.writerow(fields)
    for f in findings:
        writer.writerow([f.get(k, "") for k in fields])
    sys.stdout.write(buf.getvalue())


def main():
    parser = argparse.ArgumentParser(
        prog="vdetect.sh",
        description="CMS & Web Application Version Detector CLI (v2.0.0)",
    )
    parser.add_argument("-p", "--path", help="Comma-separated directories to scan (default: current directory)")
    parser.add_argument("-u", "--user", help="Comma-separated Linux/cPanel usernames to scan")
    parser.add_argument("-r", "--reseller", help="Scan all accounts owned by cPanel reseller")
    parser.add_argument("-a", "--all-docroots", action="store_true", help="Auto-discover all Apache/Nginx/cPanel docroots")
    parser.add_argument("-m", "--maxdepth", type=int, default=3, help="Max directory depth (-1 for unlimited, default: 3)")
    parser.add_argument("-s", "--signatures", help="External JSON or XML signatures file")
    parser.add_argument("--exclude", default="", help="Extra comma-separated directory names to skip")
    parser.add_argument("--outdated-only", action="store_true", help="Only display OUTDATED applications")
    parser.add_argument("-o", "--output", choices=["table", "json", "csv"], default="table", help="Output format")
    parser.add_argument("--cpanel-root", default="/var/cpanel", help="Custom /var/cpanel root")
    parser.add_argument("--etc-root", default="/etc", help="Custom /etc root")
    parser.add_argument("--no-color", action="store_true", help="Disable ANSI colors")
    parser.add_argument("-v", "--version", action="version", version=f"vdetect.sh {VERSION}")
    args = parser.parse_args()

    paths = []
    if args.path:
        paths.extend(p.strip() for p in args.path.split(",") if p.strip())
    if args.user:
        for u in args.user.split(","):
            u = u.strip()
            if u:
                paths.extend(get_cpanel_docroots_for_user(u, args.cpanel_root))
    if args.reseller:
        for r in args.reseller.split(","):
            r = r.strip()
            if r:
                for u in get_reseller_users(r, args.etc_root):
                    paths.extend(get_cpanel_docroots_for_user(u, args.cpanel_root))
    if args.all_docroots:
        paths.extend(discover_all_docroots(args.etc_root, args.cpanel_root))
    if not paths:
        paths = [os.getcwd()]

    signatures = list(BUILTIN_SIGNATURES)
    if args.signatures:
        signatures.extend(load_external_signatures(args.signatures))

    exclude_dirs = set(SKIP_DIRS)
    if args.exclude:
        exclude_dirs.update(x.strip() for x in args.exclude.split(",") if x.strip())

    findings = scan_paths(paths, args.maxdepth, signatures, exclude_dirs)
    if args.outdated_only:
        findings = [f for f in findings if f["status"] == "OUTDATED"]

    if args.output == "json":
        print(json.dumps(findings, indent=2))
    elif args.output == "csv":
        render_csv(findings)
    else:
        use_color = sys.stdout.isatty() and not args.no_color
        render_table(findings, Colors(enabled=use_color))


if __name__ == "__main__":
    main()
EOF

python3 -c "$PY_SCRIPT" "$@"
