# vdetect — Detector de Versões de CMS e Aplicações Web (`v2.0.0`)

Uma CLI moderna e independente em Bash + Python 3 para detectar **instalações de CMS e aplicações web** e suas versões em servidores **cPanel, Apache, Nginx e Linux**, substituindo o legado em Python 2.7 `vdetect` sem dependências externas, com assinaturas offline embutidas e saídas `table` / `json` / `csv`.

## Recursos

- **Assinaturas Offline Embutidas**: Detecta **WordPress, Joomla, Drupal, Laravel, phpMyAdmin, Roundcube, PrestaShop, OpenCart e Next.js** sem depender de servidores externos.
- **Assinaturas Externas (`-s`)**: Suporte opcional a arquivos **JSON** ou **XML** customizados.
- **Descoberta Multi-Origem**: Varre diretórios `--path`, contas `--user`, revendas `--reseller` (`/etc/trueuserowners`) ou `--all-docroots` (cPanel, Apache e Nginx).
- **Classificação de Versões**: Compara versões detectadas com baselines seguros (`CURRENT`, `OUTDATED`, `UNKNOWN`) com filtro `--outdated-only`.

## Uso

```bash
./vdetect.sh [OPÇÕES]
```

## Exemplo de Saída Real

```text
$ ./vdetect.sh -p /tmp/vdetect-e2e --no-color
=== vdetect.sh v2.0.0 | CMS & Web App Version Report ===
STATUS     APPLICATION    VERSION      MIN_SAFE   PATH
--------------------------------------------------------------------------------
CURRENT    Laravel        11.2.0       11.0.0     /tmp/vdetect-e2e/api
CURRENT    Next.js        15.0.3       14.2.0     /tmp/vdetect-e2e/app
OUTDATED   WordPress      6.4.2        6.6.0      /tmp/vdetect-e2e/blog
```

## Licença

Apache-2.0 — veja [LICENSE](LICENSE).
