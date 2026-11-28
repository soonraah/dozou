# dlt と DuckDB 向けの agent tooling の設計

| 項目 | 内容 |
|---|---|
| ステータス | 承認済み (2026-11-28) |
| 作成日 | 2026-11-27 |
| 規模 | 小さな変更 (1 branch) |
| feature | `agent-data-tooling` |
| 関連文書 | [AGENTS.md](../../../AGENTS.md) / [2026-11-27-agent-harness-minimal-design.md](2026-11-27-agent-harness-minimal-design.md) |

## 目的

次の feature `mf-csv-ingest` (MoneyForward の CSV を dlt で取り込む) を、agent が dlt の docs と実際の load の結果を確かめながら実装できるようにする。
そのために、Claude Code から次の 3 つを使える状態にする。

- `dlt-mcp`: dltHub が Apache-2.0 で公開している MCP server。pipeline と schema の確認、SQL の実行、dlt の docs と code の検索ができる。
- `llms.txt`: dlt の docs の目次 (<https://dlthub.com/docs/llms.txt>)。WebFetch で読む。
- duckdb-skills: CSV の中身の確認と、load した DuckDB の確認に使う plugin。

## 目標と非目標

目標は次のとおりである。

- `dlt-mcp` を project の MCP server として登録し、新しい session で tool を呼べる。
- agent が dlt の docs を引くときの入口として、`llms.txt` を AGENTS.md に書く。
- duckdb-skills を有効にし、CSV を読む skill が動く。

次のものは対象にしない。

- MoneyForward の CSV を取り込む pipeline の実装。これは `mf-csv-ingest` で行う。
- dltHub AI Harness (`dlt[hub]`、`dlthub` CLI、AI workbench の skills と rules)。理由は「検討した方式」に書く。

## 検討した方式

| 方式 | 利点 | 欠点 | 判定 |
|---|---|---|---|
| a. dltHub AI Harness と `filesystem-pipeline` toolkit | CSV を取り込む pipeline の雛形を作る skill がある | license が個人の利用に合わない (下記)。生成 file がこの repo の pre-commit を通らない | 不採用 |
| b. `dlt-mcp`、`llms.txt`、duckdb-skills | すべて Apache-2.0 か公開の docs。repo に vendor の file が増えない | pipeline の雛形は自分で書く。`dlt-mcp` は 2026-02 から release がない | **採用 (本人が選択)** |

方式 a を採らない理由は、dltHub の文書に次の記述があるためである。

- AI Harness の skills と rules を配る「dltHub AI Source Available License」は、利用を dltHub Services の契約のもとに限り、それ以外の利用を認めていない (<https://dlthub.com/license>)。
- この license は、skills の助けで生成した code も派生物に含める。
- Terms of Use は、dltHub Service が個人の消費者向けではないと書いている (<https://dlthub.com/legal/dlt-plus-eula>)。
- `dlthub` package が参照する EULA の本文 (<https://dlthub.com/docs/plus/EULA>) は 404 で読めない。

## 事前の確認結果

scratchpad の使い捨て project に `dlt[duckdb]==1.32.0` と `dlt-mcp[search]` を入れ、stdio で MCP server を起動して tool を呼んだ。

- `dlt-mcp` は 0.3.0 で、license は Apache-2.0 である。依存は `dlt>=1.19.0` と `fastmcp>=3.0.0` で、`dlthub` には依存しない。
- tool は `list_pipelines`、`list_tables`、`get_table_schema`、`execute_sql_query`、`get_load_table`、`get_pipeline_local_state`、`get_table_schema_diff`、`search_docs`、`search_code`、`display_schema` の 10 個である。
- `list_pipelines` は `~/.dlt/pipelines/` にある既存の pipeline (`from_database`、`money_forward`、`quick_start`) を返した。以前の repo で作ったものと思われる。
- `search_docs` は、最新の依存 (`lancedb` 0.41.0、`chonkie` 1.7.0) では `Field 'metadata' not found in target schema` で失敗した。`lancedb>=0.25.3,<0.26` と `chonkie[code,model2vec]==1.4.2` に固定すると成功し、`read_csv` などの reader の説明が返った。
- `search_docs` が引く docs の index は dlt 1.18.1 のものである (`~/.dlt/mcp/docs_1-18-1.lancedb`)。この repo の dlt 1.32.0 より古い。

## 設計

### 依存関係

`pyproject.toml` の `dev` group に次を足し、`uv.lock` を更新する。

- `dlt-mcp[search]>=0.3.0,<0.4`
- `lancedb>=0.25.3,<0.26`
- `chonkie[code,model2vec]==1.4.2`

`lancedb` と `chonkie` は直接は使わないが、`search_docs` を動かすために version を固定する。
固定の理由を `pyproject.toml` に comment で書く。
`dlt-mcp` を新しい version に上げるときに、この固定を外せるかを確かめる。

### MCP server の登録

repo root に `.mcp.json` を置く。

```json
{
  "mcpServers": {
    "dlt": {
      "command": "uv",
      "args": ["run", "--frozen", "python", "-m", "dlt_mcp"]
    }
  }
}
```

`uv run --frozen` を使うので、MCP server は `uv.lock` で固定した version で動き、network を使わない。
ただし `search_docs` は、初回に docs の index と embedding の model を download する。

`.claude/settings.json` に `enabledMcpjsonServers: ["dlt"]` を足す。
これがないと、新しい session を始めるたびに `.mcp.json` の server を使うかを人間に聞くことになる。

### dlt の docs の引き方

AGENTS.md の「作業の進め方」に、次の順で docs を引くことを 1 行で書く。

1. `dlt` MCP server の `search_docs`。
2. 見つからないとき、または index が古いと疑われるときは、`llms.txt` から該当ページを WebFetch で読む。

`search_docs` の index は dlt 1.18.1 のものなので、API の細部は `llms.txt` の側で確かめる。

### telemetry

dlt は既定で匿名の telemetry を送る。
個人の data 基盤なので、`.dlt/config.toml` に次を書いて止める。

```toml
[runtime]
dlthub_telemetry = false
```

### duckdb-skills の導入

duckdb-skills は Anthropic Directory の community plugin である。
導入は人間が claude.ai の plugin card から行う (Interventions には `permission` として記録する)。
repo には設定を残さない。

duckdb-skills の skill は DuckDB の CLI を使う。
今の Mac には `duckdb` の CLI がないので、`install-duckdb` skill か Homebrew で入れる。
どちらで入れるかは builder が決め、`claude-progress.md` に記録する。

### AGENTS.md の更新

- プロジェクト構成の表に `.mcp.json` と `.dlt/` を足す。
- 「作業の進め方」に、dlt の docs の引き方を書き足す。

## 完了基準

次のすべてを、実行した command と結果で示す。

1. `bash init.sh` が exit 0 で終わる。
2. `uv tree --frozen` に `dlthub` が含まれない。
3. 新しい session で、次を確認する。
   - `/mcp` で `dlt` server が connected になっている (人間が確認)。
   - `list_pipelines` と `search_docs` (例: `read_csv encoding`) を 1 回ずつ呼び、どちらも成功する。
4. duckdb-skills の `read-file` skill で、repo に commit しない小さな sample CSV (Shift_JIS、3 行程度) を読み、列名と行数が返る。MoneyForward の実データは使わない。
5. `python -m json.tool .mcp.json` と `python -m json.tool feature_list.json` が通る。

## 未確定のこと

- `dlt-mcp` は 2026-02 から release がない。止まったままなら、`search_docs` を諦めて `llms.txt` だけにすることを、次に依存を更新するときに検討する。
- `~/.dlt/pipelines/` の既存の pipeline は、この repo のものではない。`mf-csv-ingest` で pipeline 名が衝突しないよう、そちらの spec で名前を決める。

## builder に任せること

- AGENTS.md に足す文面と、`pyproject.toml` の comment の文面。
- DuckDB の CLI の入れ方。
- sample CSV の中身と置き場所 (scratchpad など、repo の外)。
