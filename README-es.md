# vdetect — Detector de Versiones de CMS y Aplicaciones Web (`v2.0.0`)

![vdetect cover](vdetect-cover.webp)

Una CLI moderna e independiente en Bash + Python 3 para detectar **instalaciones de CMS y aplicaciones web** y sus versiones en **cPanel, Apache, Nginx y Linux**, reemplazando el legado en Python 2.7 `vdetect` sin dependencias externas, con firmas offline integradas y salidas `table` / `json` / `csv`.

## Características

- **Firmas Offline Integradas**: Detecta **WordPress, Joomla, Drupal, Laravel, phpMyAdmin, Roundcube, PrestaShop, OpenCart y Next.js** sin llamadas de red externas.
- **Firmas Externas (`-s`)**: Soporta archivos **JSON** o **XML** personalizados.
- **Descubrimiento Multi-Origen**: Escanea `--path`, cuentas `--user`, revendedores `--reseller` (`/etc/trueuserowners`) o `--all-docroots`.
- **Clasificación de Versiones**: Compara versiones detectadas (`CURRENT`, `OUTDATED`, `UNKNOWN`) con filtro `--outdated-only`.

## Uso

```bash
./vdetect.sh [OPCIONES]
```

## Ejemplo de Salida Real

```text
$ ./vdetect.sh -p /tmp/vdetect-e2e --no-color
=== vdetect.sh v2.0.0 | CMS & Web App Version Report ===
STATUS     APPLICATION    VERSION      MIN_SAFE   PATH
--------------------------------------------------------------------------------
CURRENT    Laravel        11.2.0       11.0.0     /tmp/vdetect-e2e/api
CURRENT    Next.js        15.0.3       14.2.0     /tmp/vdetect-e2e/app
OUTDATED   WordPress      6.4.2        6.6.0      /tmp/vdetect-e2e/blog
```

## Licencia

Apache-2.0 — ver [LICENSE](LICENSE).
