# dozou 向け Claude Code security 設定の設計

| 項目 | 内容 |
|---|---|
| ステータス | 第 3 版、承認済み (受け入れ確認は未完了) |
| 作成日 | 2026-11-23 |
| 関連文書 | [03-refinement.md](../../strategies/personal-data-platform/03-refinement.md) |

## 目的

dozou の開発では、最終的に Claude Code を長時間自律的に動かしたい。
一方で、この repo は public であり、同じ Mac には他サービスの認証情報もある。
そこで、agent が認証情報と実データを読めない状態を保ちつつ、運用の手間を増やさない設定を作る。

第 2 版では実行ごとの clone と専用 runner を検討したが、運用が複雑になるため採用しなかった。
第 3 版は、普段の checkout と project 設定だけで動かし、残るリスクを明示して許容する。

## 目標と非目標

目標は次の 4 つである。

- agent が認証情報の置き場所、1Password、実データを読めない。
- agent が GitHub へ push できない。
- agent が auto mode で、確認待ちを減らして開発と commit を続けられる。
- 認証情報や data を誤って commit、push しにくい。

次の 4 つは対象にしない。

- user scope の設定変更 (他 project の運用を変えないため)。
- LLM provider に渡る会話内容の制御 (診断で、守る重心を認証情報に置いたため)。
- 通信先の完全な制限 (project 設定では `strictAllowlist` を使えないため)。
- 実データを使う取り込みや S3 同期の自動化 (これらは本人が `op run` で実行する)。

## 検討した方式

| 方式 | 利点 | 欠点 | 判定 |
|---|---|---|---|
| A. project 設定と auto mode | 手間が最小で、desktop app をそのまま使える | 通信先の制限と、agent が書いた code の隔離は完全ではない | 採用 |
| A + 使い捨て clone と runner | 通信先を強制でき、人の checkout を隔離できる | 実行と取り込みの手順が増える | 運用が複雑なため不採用 |
| B. `claude --settings` の専用 launcher | user scope 限定の設定も使える | terminal 起動に限られる | 不採用 |
| C. container 隔離 | home directory を見せずに済む | image と mount の保守が運用予算を圧迫する | 不採用 |

## 設計

### 維持する設定

- sandbox を必須にし、sandbox 外での再実行を禁止する。
- 認証情報の置き場所と 1Password の領域の読み取りを禁止する。
- `op`、connector、Chrome、built-in browser、Terminal panel、scheduled task、個人用 MCP server を禁止する。
- GitHub と npm への Bash の通信を禁止する。push と PR 作成は本人が行い、そこを最終確認の場にする。
- `.claude/settings*.json`、`.mcp.json`、`.git/config`、`.git/hooks/` への書き込みを禁止する。
- `.gitignore` と gitleaks の pre-commit hook で誤公開を防ぐ。server 側では GitHub push protection を有効にする。

### 変更する設定

- `disableAutoMode` を削除し、auto mode を使えるようにする。
- 実データを repo の外の `~/dozou-data` に置き、読み取りを禁止する。agent は `data/sample/` で開発する。
- `.dlt/secrets.toml` と、入れ子の `.env`、`.env.*` の読み取りを禁止する。
- `.git/commondir`、`.tool-versions`、`.envrc`、`.gitleaks.toml`、`.gitleaksignore` への書き込みを禁止する。本人の git や asdf の操作で、agent の細工が sandbox の外で動く主な経路を塞ぐためである。
- Bash の通信先に `extensions.duckdb.org` を追加し、local port の bind を許可する。
- cache を repo 内の `.cache/` に向ける。絶対 path を public repo に出さないよう、この環境変数は git 管理外の `.claude/settings.local.json` に置く。

## 許容するリスク

1. 未許可の host に通信できる場合がある。認証情報と実データは読めないため、持ち出され得るのは主に public な code と会話内容である。
2. agent が書いた code は、本人が実行すると sandbox の外で動く。`op run` で実行する前に、本人が差分を確認する。
3. 入れ子の `.git` や `.vscode` の設定など、細かい迂回経路は残る。
4. 操作の可否は auto mode の判断に任せる。

## 既知の制約

sandbox 内の DuckDB は、既定の設定では extension を install できない。
既定の `~/.duckdb` に書き込めず、sandbox の proxy 環境変数も parse できないためである。
DuckDB の接続処理を実装するときに、`extension_directory` を `.cache/duckdb/extensions` に向け、proxy を `http_proxy`、`http_proxy_username`、`http_proxy_password` に分けて設定する。

## 受け入れ条件

1. sandbox 内の Bash と Read tool から、認証情報の置き場所を読めない。
2. sandbox 内の Bash から `github.com` に接続できず、`git push` も失敗する。
3. `pypi.org` からの取得と local port の bind が成功する。
4. `.git/commondir`、`.tool-versions`、`.envrc`、gitleaks の設定 file に書き込めない。
5. agent が sandbox 内で通常の commit を作成できる。
6. dummy の secret を含む commit を gitleaks が止める。
7. 本人が sandbox 内の Bash から `op vault list` を実行し、失敗することを確認する。
8. 最初の長時間実行で、auto mode が確認待ちで止まらないことを確認する。

## 実装者に任せる事項

- 検証 script の項目の細部。
