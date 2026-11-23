# dozou 向け Claude Code security 設定の設計

| 項目 | 内容 |
|---|---|
| ステータス | 承認済み (受け入れ確認は未完了) |
| 作成日 | 2026-11-23 |
| 関連文書 | [03-refinement.md](../../strategies/personal-data-platform/03-refinement.md) |

## 目的

dozou の戦略テストでは、Claude Code に実装を任せる。
この repo は public であり、同じ Mac には他サービスの認証情報もある。
そこで、agent が認証情報を読めず、repo の内容や data を外部へ持ち出しにくい状態を、実装の開始前に作る。

## 目標と非目標

目標は次の 4 つである。

- sandbox 内の Bash から、認証情報の置き場所と 1Password を利用できない。
- Bash 以外の tool (WebFetch、MCP、connector) からの流出経路を絞る。
- agent が GitHub へ push できない。
- 認証情報や data を誤って commit、push しにくい。

次の 3 つは対象にしない。

- user scope の設定変更 (他 project の運用を変えないため)。
- LLM provider に渡る会話内容の制御 (診断で、守る重心を認証情報に置いたため)。
- 悪意ある依存 package を完全に防ぐこと (network と読み取りの制限で被害を抑えるにとどめる)。

設定によって開発が止まり、運用が月 1 時間を超える状態は失敗とみなす。

## 検討した方式

| 方式 | 利点 | 欠点 | 判定 |
|---|---|---|---|
| A. project 設定 | 手間が小さく、repo で管理でき、desktop app でも使える可能性がある | 隔離は OS sandbox と permission rule に依存する | 採用 |
| B. `claude --settings` の専用 launcher | user scope 限定の設定も使える | terminal 起動に限られ、起動方法を守る必要がある | A が desktop app で機能しない場合の代替 |
| C. container 隔離 | home directory を見せずに済む | image、mount、DuckDB UI の接続を保守する必要がある | 運用負荷が大きいため不採用 |

## 設計

### 設定の置き場所

共有できる rule は `.claude/settings.json` に置く。
public repo に出したくない個人環境固有の rule (個人用 MCP server の名前など) は、git 管理外の `.claude/settings.local.json` に置く。
deny rule はどの scope に書いても有効である。

### Bash の隔離

- `sandbox.enabled` と `failIfUnavailable` を `true` にし、sandbox を起動できない場合は Claude Code も起動しない。
- `allowUnsandboxedCommands` を `false` にし、sandbox 外での再実行を禁止する。
- `excludedCommands`、`allowUnixSockets`、`allowMachLookup` は設定しない。これにより 1Password と SSH agent への通信経路を開けない。
- network の許可先は `pypi.org` と `files.pythonhosted.org` から始め、必要が生じたら個別に追加する。`github.com` は持ち出し経路になるため許可しない。

### 認証情報の読み取り禁止

`Read` の deny rule に次の場所を列挙する。
この rule は Read tool に効き、sandbox の `denyRead` にも反映される。

- `~/.ssh`、`~/.gnupg`、`~/.aws`、`~/.config/gh`、`~/.config/gcloud`、`~/.config/op`、`~/.kube`
- `~/.docker/config.json`、`~/.dbt`、`~/.dlt`、`~/.duckdb`
- `~/Library/Keychains`、1Password の application data
- repo 内の `.env`、`.env.*`、`secrets/`

環境変数は `sandbox.credentials.envVars` の deny で、GitHub と AWS の token を Bash に渡さない。

### Bash 以外の経路

- `disableClaudeAiConnectors` を `true` にし、Gmail などの connector を dozou で無効にする。
- Chrome、built-in browser、Terminal panel、scheduled task、個人用 MCP server の tool を deny にする。Terminal panel の tool は sandbox の外で command を実行できるため、塞ぐ必要がある。
- `mcp__*` の一括 deny は使わない。desktop app 自身の task list などの tool まで止めるためである。
- `disableAutoMode` で auto mode を無効にする。WebFetch は開発に使う文書の domain だけを allow にし、それ以外は確認を求める。
- agent が防御を解除できないよう、`.claude/settings*.json`、`.mcp.json`、`.git/config`、`.git/hooks/` への Edit を deny にする。

### repo の誤公開対策

- `.gitignore` に `.env*`、`.claude/settings.local.json`、data directory、DuckDB と DuckLake の file を追加する。sample data だけを追跡対象にする。
- gitleaks を pre-commit で実行する。agent は hook を迂回できる可能性があるため、これは補助策である。
- server 側の防御として GitHub の push protection を有効にする。
- push と PR 作成は、本人が自分の terminal で行う。

## 受け入れ条件

実装後、実際に次を試して確認する。

1. sandbox 内の Bash から `~/.ssh` と `~/.aws` の一覧を取得できない。
2. Read tool で認証情報の置き場所を読めない。
3. sandbox 内の Bash から許可外の domain と `github.com` に接続できず、`git push` も失敗する。
4. `pypi.org` からの package 取得は成功する。
5. connector、Chrome、Terminal panel の tool を使えない。
6. agent が `.claude/settings.json` を編集できない。
7. dummy の secret を含む commit を gitleaks が止める。
8. `op` の install 後、sandbox 内の Bash から `op whoami` と `op vault list` が失敗する。この確認は本人が行う。

## 未確認の事項

- desktop app の Code tab で sandbox が有効になるか。無効なら方式 B に切り替える。
- login Keychain への到達可否。公式 docs に記載がないため、受け入れ確認の際に試す。
- `sandbox.credentials` の deny が、`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` なしで環境変数を除去するか。

## 実装者に任せる事項

- WebFetch の許可 domain の具体的な一覧。
- data directory の名前と `.gitignore` の細部。
- gitleaks の導入方法。
