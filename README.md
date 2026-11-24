# vdetect — CMS & Web Application Version Detector (`v2.0.0`)

A modern, standalone Bash + Python 3 CLI for detecting **CMS & web application installations** and their versions across **cPanel, Apache, Nginx, and standalone Linux** directories — replacing legacy Python 2.7 `vdetect` with zero external dependencies, built-in offline signatures, and `table` / `json` / `csv` outputs.

## Features

- **Built-In Offline Signatures**: Detects **WordPress, Joomla, Drupal, Laravel, phpMyAdmin, Roundcube, PrestaShop, OpenCart, and Next.js** out of the box with no external network requests required.
- **External Signature Support (`-s`)**: Optionally load custom **JSON** or **XML** signature definitions.
- **Multi-Source Discovery**: Scan explicit `--path` trees, `--user` cPanel/Linux accounts, `--reseller` accounts (`/etc/trueuserowners`), or `--all-docroots` across cPanel, Apache, and Nginx configs.
- **Outdated Version Flagging**: Compares detected versions against baseline safe releases (`CURRENT`, `OUTDATED`, `UNKNOWN`) with `--outdated-only` filtering.
- **Multiple Formats**: `table` (default), `json`, and `csv`.

## Usage

```bash
./vdetect.sh [OPTIONS]
```

| Flag | Description |
| :--- | :--- |
| `-p, --path <dir[,dir...]>` | Comma-separated directories to scan (default: CWD) |
| `-u, --user <user[,user...]>` | Scan cPanel/Linux user document roots |
| `-r, --reseller <user>` | Scan all accounts owned by a cPanel reseller |
| `-a, --all-docroots` | Auto-discover Apache/Nginx/cPanel document roots |
| `-m, --maxdepth <N>` | Max directory depth (`-1` unlimited, default: `3`) |
| `-s, --signatures <file>` | Load extra JSON or XML signatures |
| `--outdated-only` | Show only `OUTDATED` applications |
| `-o, --output <fmt>` | Output format: `table`, `json`, or `csv` |
| `-v, --version` | Show version (`2.0.0`) |

## Real Output Example

```text
$ ./vdetect.sh -p /tmp/vdetect-e2e --no-color
=== vdetect.sh v2.0.0 | CMS & Web App Version Report ===
STATUS     APPLICATION    VERSION      MIN_SAFE   PATH
--------------------------------------------------------------------------------
CURRENT    Laravel        11.2.0       11.0.0     /tmp/vdetect-e2e/api
CURRENT    Next.js        15.0.3       14.2.0     /tmp/vdetect-e2e/app
OUTDATED   WordPress      6.4.2        6.6.0      /tmp/vdetect-e2e/blog
```

## License

Apache-2.0 — see [LICENSE](LICENSE).
