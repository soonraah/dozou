# 探究: 個人用データ基盤のアーキテクチャ方針

| 項目 | 内容 |
|---|---|
| 戦略名 | 個人用データ基盤 (dozou) のアーキテクチャ方針 |
| ステータス | レビュー中 |
| 作成日 | 2026-11-21 |
| 最終更新日 | 2026-11-21 |
| 質問の窓口 | soonraah (本人) |

## 探究のスコープ

- この戦略で決めること: 個人データ (健康・家計・ダイビング・健診・タスク) を集約する基盤の技術スタック (ingestion / storage / table format / query engine / pipeline / BI / MCP 接続) の方針。要件は [requirement.md](requirement.md)。
- 探究の重心: 社外寄り。組織は本人 1 人で、「社内の前例」に当たるのは本人の業務経験 (Databricks 基盤) だけである。
- 時間箱: 最小 2 時間 / 最大 4 時間。実績は 2 ラウンドで Web 検索 21 本、深掘り 11 件。所要はおよそ 2 時間 (エージェント側の作業時間の目安)。2 ラウンド目は、出発点と矛盾する主張を狙って検索の切り口を変えた。
- 深掘り対象は本来は本人が選ぶべきところを、時間箱の都合でエージェントが選んだ。入れ替えは可能。

## 要約

選択肢は大きく 5 系統あった。(1) 中央 DB を持たず、生 export を Python module 経由で読む [HPI](https://github.com/karlicoss/HPI)。(2) SQLite + Datasette + 各種 `*-to-sqlite` で組む [Dogsheep](https://simonwillison.net/2020/Nov/14/personal-data-warehouses/)。(3) ローカル DuckDB (± DuckLake) + dbt。出発点の構成で、dev.to にも同種の記事が多い。(4) 中央の warehouse を作らず、データソースごとに MCP server を立てて LLM から直接引く ([apple-health-mcp](https://github.com/neiltron/apple-health-mcp)、goetta-finance など)。(5) Databricks Free Edition / BigQuery sandbox / MotherDuck などクラウドの無料枠。ingestion はこれとは別の軸で、dlt、手書きの script、Airbyte などがある。

実際に個人でやっている人の多くは「ローカルの単一ファイル DB + cron + 自作の取り込み script」に落ち着いている。Willison は「1 ファイルでコピー・バックアップ・デプロイが容易」という理由で SQLite を選んだ。HPI の作者は「DB は個人データには硬すぎ、どのみちコードを書くことになる」として DB を持つこと自体を避けた。クラウドの無料枠は手軽だが、それぞれ前提条件がある。Databricks Free は非商用限定で、長期間使わない account は削除されうるうえ、外向きの通信も限られる。BigQuery sandbox には table の有効期限がある (未確認)。Snowflake には 30 日の trial しかない。

出発点からの最大の変化は、**security 境界が storage ではなく LLM 側にある** と分かったことである。cloud 型の Claude を MCP client にすれば、データをどこに置いても query 結果は手元の machine の外に出る ([Saubury](https://dev.to/saubury/i-dont-need-an-untrusted-llm-to-tell-me-im-spending-too-much-on-coffee-57kn) は明言している)。さらに Claude Code は Web にアクセスできるので、Willison のいう [lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) (private data / untrusted content / 外部への通信) が揃いうる。MotherDuck の MCP server の README も、read-only mode だけでは不十分だと書いている。以前の調査は storage の暗号化とバックアップに厚かったが、この観点はなかった。もう 1 つの変化は、**ingestion の制約がデータソース側で強い** ことである。Oura は Personal Access Token を廃止して OAuth2 に移った。MoneyForward には公式の個人向け API が見つからず、export は月単位の CSV だけだった。

2 ラウンド目では、「基盤をどう作るか」より手前の論点が出てきた。Quantified Self の実践者 52 人の発表を分析した [Choe et al. (CHI 2014)](http://dx.doi.org/10.1145/2556288.2557372) は、典型的な落とし穴として「記録するものが多すぎる」「きっかけや文脈を記録していない」「科学的な厳密さを欠く」を挙げている。分析の障壁として、時間と動機の不足、分析 tool の不適合、複数 platform へのデータの分散も挙げている。lifelogging の先駆者 Gordon Bell も、価値をもたらさなかったとして記録をやめた ([MIT Technology Review, 2016](https://www.technologyreview.com/2016/04/19/160909/life-logging-is-dead-long-live-life-logging/))。requirement.md には「どのデータソースを集めるか」はあるが、「どんな問いに答えたいか」がない。また、データソースの側が公式の MCP を出し始めている。Todoist には公式の remote MCP と Claude 用 connector がある。そのため、データソースによっては基盤を経由せずに Claude から直接つなぐという選択肢も現実的になった。

分かっていないことは次のとおり。この基盤で答えたい問いは何か。threat model (何を、誰から守るのか) が未定義である。MCP 経由で LLM に渡してよいデータの範囲も決まっていない。Anthropic の consumer account では、training の opt-in を有効にすると保持期間は 5 年になる。ただし、MCP の結果がこの保持の対象に含まれるかは公式の page に記載がない。各データソースの更新頻度と、手作業をどこまで許容するかも分からない。BI が本当に要るのか、LLM との対話で足りるのかも分からない。これらは診断で確かめる。

## 出発点の見立て (探究前)

- 最有力だと思っていたアプローチ: 以前の調査 ([個人用プライバシー重視データ基盤：DuckDB 中心構成の調査と推奨](https://claude.ai/artifact/AgKwjcoBMNNtXEKNaaE1JF)) の推奨構成。DuckDB + DuckLake (暗号化モード) + restic による暗号化オフサイトバックアップ (Backblaze B2) + Evidence / DuckDB UI + dbt-duckdb + cron / systemd timer。月額 0〜100 円。
- そう考えた根拠: 上記調査の結論。加えて、本人が業務で lakehouse 構成 (Databricks + dbt + Delta Lake) に慣れていること。
- 過去に似た問題を解いた経験: 業務で、所属企業のデータ基盤 (Databricks + dbt + Lakeflow Jobs + Delta Lake + S3、TB 級) を開発・運用している。
- 以前の調査で手薄だった観点: data ingestion、MCP 接続、「基盤を作らない」という選択肢。
- 以前の調査に含まれていて今回再検証していないもの: DuckLake 1.0 の日付、B2 / R2 の料金、DuckDB 2.0 LTS の情報。**以前の調査による・今回未検証** として扱う。

### 過去の経験は今も有効か

| 観点 | 当時 (業務) | 現在 (個人) | 差が効くか |
|---|---|---|---|
| 時期 | 現在進行中 | 2026-11 | 効かない |
| 組織規模・チーム構成 | チームで開発・運用 | 本人 1 人が利用者兼運用者 | 効く。運用の手間がそのまま本人の負担になる |
| データ量 | TB 級 | 小さい (具体量は未計測) | 効く。分散処理と lakehouse の利点の多くが消える |
| 使えた基盤・マネージドサービス | Databricks (有償)、S3 | 無料または低コストに限る | 効く |
| 制約 | 業務上の SLA、複数利用者 | 個人情報、低コスト、手間の小ささ、MCP 接続 | 効く。MCP / LLM 接続は業務にない要件 |
| うまくいった理由 | 不明 (本人に未確認) | — | — |

判定: 一部しか成立しない。lakehouse の設計知識 (layering、dbt によるモデリング) は移植できる。一方、table format やカタログといったスケールのための仕組みと、「保守するチームがいる」という前提は個人には移植できない。

## 社内の前例

組織は本人 1 人なので、社内チームの前例はない。唯一の前例は本人の業務基盤である。

### 業務のデータ基盤 (所属企業)

- 時期・規模: 現在、TB 級
- 課題: 組織のデータ集約と分析
- 採ったアプローチ: Databricks + dbt + Lakeflow Jobs + Delta Lake + S3
- 捨てたアプローチ: 今回は聞いていない
- 判断の背後にあった考え方: 今回は聞いていない
- 保守されている状態か: 業務では保守されている。ただし書籍のいう「すでに実装されていて保守している人がいる」という利点は、個人の基盤には **持ち込めない**。個人の基盤を保守するのは本人だけである。
- 参照: なし (社内ドキュメントは参照していない)

## 業界の事例

終了条件の「似た企業 3 社」は、個人規模の課題なので **個人の実践者 3 人** (Willison、karlicoss、Saubury) と読み替えた。

### Simon Willison — Dogsheep / Datasette

- 自社との距離: 似た規模と制約 (個人)。ただし公開する前提が強い
- 時期・規模: 2020 年。GitHub、Twitter、Foursquare、Apple Photos、HealthKit、23andMe などを取り込んでいる
- 課題: 散らばった個人データを手元で横断検索・分析したい
- 採ったアプローチ: SQLite の 1 ファイルを Datasette で閲覧する。取り込みは `*-to-sqlite` という小さな CLI 群と sqlite-utils で、API 系は cron で更新する。健康データは手作業で export する。時点データは git scraping で履歴を残す
- 捨てたアプローチ: hosted DB (コスト)、hosted Dogsheep サービス (他人の個人データを預かるリスク)、非エンジニア向けのセルフホスト (複雑で危険)、API への都度問い合わせ (手元に全量コピーを持つほうを選んだ)
- 判断の背後にあった考え方: SQLite はどこにでもあり、1 ファイルなのでコピー・バックアップ・デプロイが容易。全量を手元に持てば任意の SQL を書ける
- 結果: 本人は継続して tool を出している (dogsheep tag の記事は 31 件)。ただ、現在も個人の warehouse として使い続けているかは公開されていない
- この情報源が語っていないと思われること: 取り込み script の保守負担 (上流 API の仕様変更への追従) にどれだけ時間がかかっているか
- 出典: https://simonwillison.net/2020/Nov/14/personal-data-warehouses/ (2020-11-14)

### karlicoss — HPI (Human Programming Interface)

- 自社との距離: 似た規模と制約 (個人、プログラマ)
- 時期・規模: 日付不明 (継続して開発中の repository)
- 課題: すべての個人データに offline の programmatic API でアクセスしたい
- 採ったアプローチ: 中央 DB を持たない。cron で各サービスの export をディスクに同期し、Python package `my` の module が生ファイルを parse して正規化した object を返す。速度は cachew による cache で補う
- 捨てたアプローチ: 1 つの大きな DB への集約、cloud silo、vendor の UI への依存
- 判断の背後にあった考え方: DB は個人データの多様さに対して硬すぎ、どのみちコードを書くことになる。いちばん難しいのは取り込みである
- 結果: 本人は "a little crude, but it's real and working" と書いている。community fork もある
- この情報源が語っていないと思われること: 上流の export 形式が変わったときの追従コスト。SQL や BI で分析したくなったときの不便さ
- 出典: https://github.com/karlicoss/HPI (日付不明)

### Simon Aubury (saubury) — ローカル LLM + MCP + DuckDB で家計分析

- 自社との距離: 似た規模と制約 (個人、家計データ、プライバシー重視)
- 時期・規模: 5 月 14 日公開 (年は不明)。取引は約 3 万 500 件
- 課題: 機微な家計データを LLM で分析したいが、cloud には出したくない
- 採ったアプローチ: Moneydance から DuckDB に 1 回だけ export し、`mcp-server-motherduck` でローカルファイルに接続する。Claude Code を MCP host にして、Ollama で動かすローカル model (qwen3.5:27b) から問い合わせる
- 捨てたアプローチ: cloud の LLM にデータを渡すこと (複雑な query のときだけ fallback として使う)、cloud の家計管理アプリ、継続的な同期
- 判断の背後にあった考え方: 個人データを「void に投げ込まない」こと
- 結果: PoC としては成功した。一方で、ローカル model は「とても遅い」。複雑な query には cloud model が必要になり、そうするとプライバシーの保証が崩れる
- この情報源が語っていないと思われること: 継続運用 (データの更新) をどうするか。1 回きりの export なので、そもそも運用を想定していない
- 出典: https://dev.to/saubury/i-dont-need-an-untrusted-llm-to-tell-me-im-spending-too-much-on-coffee-57kn (年不明)

### Quantified Self 実践者 52 人 (Choe et al., CHI 2014) と Gordon Bell

- 自社との距離: 似た規模と制約 (個人の self-tracking)。ただし 2014 年当時の話で、LLM はなかった
- 時期・規模: Quantified Self Meetup の発表動画 52 本を質的・量的に分析したもの
- 課題: 個人データを集めて、そこから学びを得たい
- 採ったアプローチ: 既製の tool を使い、足りないところは自作で補う
- 落とし穴: 記録するものが多すぎる。きっかけや文脈を記録していない。科学的な厳密さを欠く
- 分析の障壁 (先行研究として引用されているもの): 時間と動機の不足、分析・可視化 tool の不適合、分析の skill、複数 platform へのデータの分散
- Gordon Bell: lifelogging の先駆者。価値をもたらさなかったとして記録をやめた (MIT Technology Review, 2016)
- 判断の背後にあった考え方: 「数字による自己理解」への信念
- 結果: 多くの人が記録を一時的に中断するか、やめてしまう (検索結果の要約にもとづく)
- この情報源が語っていないと思われること: 記録を続けられた人が何を変えたのか。LLM で分析のコストが下がった今、障壁のうちどれが残るのか
- 出典: http://dx.doi.org/10.1145/2556288.2557372 (2014-04) / https://www.technologyreview.com/2016/04/19/160909/life-logging-is-dead-long-live-life-logging/ (2016-04-19)

### クラウド無料枠 (Databricks Free / BigQuery sandbox / Snowflake / MotherDuck)

- 自社との距離: 前提が違う (組織向け製品の無料枠)
- 内容は下の「見つかった選択肢の幅」と、ingestion の制約の表にまとめた。
- この情報源が語っていないと思われること: 無料枠の条件変更の頻度。Community Edition から Free Edition への移行のように、条件は変わりうる。

## 論文・書籍・講演

| 資料 | 種類 | 公開日 | ここから得たこと | リンク |
|---|---|---|---|---|
| The lethal trifecta for AI agents (Simon Willison) | 記事 | 2025-06-16 | private data / untrusted content / 外部への通信 の 3 つが揃うと prompt injection で情報が漏れる。防ぐには 3 本の足のどれかを断つしかない | https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/ |
| Understanding Quantified-Selfers' Practices in Collecting and Exploring Personal Data (Choe et al.) | 論文 (CHI 2014) | 2014-04 | self-tracking の落とし穴と分析の障壁 (上記) | http://dx.doi.org/10.1145/2556288.2557372 |
| Anthropic の privacy policy の更新 | 公式 page | 2026-06-08 掲載 / 2026-07-08 施行 | consumer account (Free / Pro / Max、それらで使う Claude Code を含む) は、training の opt-in を有効にすると保持期間が 5 年になる。MCP や tool の結果の扱いは記載なし | https://privacy.claude.com/en/articles/10301952-updates-to-our-privacy-policy |
| Claude Code の sandboxing / permissions | 公式 docs と issue | 日付不明 | 外への通信を制御できる。ただし sandbox の対象は Bash だけで、WebFetch と MCP には別の permission が要る。設定どうしが干渉するという issue の報告もある (未検証) | https://code.claude.com/docs/en/sandboxing |
| Talk Python #299: Personal search engine with Datasette and Dogsheep | 講演 (podcast) | 日付不明 | Dogsheep の背景 (未読、言及のみ) | https://talkpython.fm/299 |
| Why you should use a data warehouse (PostHog) | 記事 | 日付不明 | データが数百万行以下なら warehouse は過剰で、まず DuckDB のようなローカル tool から始めよという主張 (検索結果の要約による) | https://posthog.com/blog/why-you-should-use-a-data-warehouse |

## 実務担当者から聞いたこと

| 誰に | その人の文脈 | 聞いたこと | 自社との条件の違い |
|---|---|---|---|
| なし | — | — | — |

聞ける人はいない (本人に確認済み)。書籍は security を「実務担当者に直接聞かないと十分に学べない領域」に挙げている。今回の戦略は個人情報と LLM 接続という security の論点を含むので、**既知の欠落** として残す。

## 見つかった選択肢の幅

ここでは優劣を判定しない。

### アーキテクチャの系統

| 選択肢 | 概要 | 採っている例 | 成立条件 | 未確認の点 |
|---|---|---|---|---|
| A. 中央 DB なし (code over raw exports) | 生 export をファイルとして保持し、Python module で parse して使う | HPI (karlicoss) | Python で分析することに抵抗がない。SQL や BI の要求が弱い | MCP からの使い勝手。SQL で横断分析したくなったときの移行コスト |
| B. SQLite + Datasette | 1 ファイルの SQLite。`*-to-sqlite` で取り込み、Datasette で閲覧する | Dogsheep (Willison) | 行指向でも集計が十分に速い程度のデータ量 | 2026 年時点の Dogsheep tool 群の保守状況 |
| C. ローカル DuckDB (± DuckLake) + dbt | 列指向のローカル DB。lakehouse 風の layering | 出発点の構成、dev.to の多数の記事、Saubury | 1 台の machine で完結できる。単一 writer の制約を許容できる | DuckLake の運用負荷を個人規模で実際に測っていない |
| D. データソースごとの MCP server (warehouse なし) | データソースごとに local MCP server を立て、LLM が直接引く | apple-health-mcp、goetta-finance、Quicken MCP | 横断分析より、データソースごとの対話で足りる | データソースをまたぐ join を LLM 任せにしたときの正確さ |
| E. クラウド無料枠の warehouse | Databricks Free Edition、BigQuery sandbox、MotherDuck free | 業務経験の延長 | 個人データを第三者のクラウドに置くことを許容できる。無料枠の条件変更を許容できる | 下の個別表を参照 |
| F. 無料枠の managed Postgres | Supabase Free (使わないと 1 週間で停止、2 project まで、500 MB) / Neon Free (scale-to-zero、0.5〜1 GB は情報が食い違う) | 今回は個人データでの事例が見つからなかった | E と同じ。容量が小さいことを許容できる | 第三者情報にもとづく。容量は公式 page で未確認 |
| G. データソースの公式 MCP / connector を直接使う (基盤を作らない) | 例: Todoist の公式 remote MCP (`ai.todoist.net/mcp`) と Claude 用 connector (OAuth) | Todoist 公式 | 横断分析が要らない。データソース側の保持と API に依存してよい | 完了済み task や履歴を読めるか。Oura には公式 MCP が見つからなかった (community 製はある) |

### ingestion の実行場所

| 選択肢 | 分かったこと | 未確認 |
|---|---|---|
| 手元の machine で cron / launchd | 出発点の想定 | machine が sleep しているときの取りこぼし |
| GitHub Actions (private repo) で定期実行 (git scraping 型) | cron の最短間隔は 5 分。secret は暗号化された vault に置ける。private repo では Actions が有料枠の対象になる。SQLite の binary を毎回 commit すると履歴が膨らむので、artifact に置く例がある。commit した内容は git の履歴に残る | 個人の健康・家計データを GitHub の runner と repo に置くことの是非 (threat model しだい) |

### クラウド無料枠の条件

| サービス | 分かったこと | 未確認 |
|---|---|---|
| Databricks Free Edition | serverless のみ。SQL warehouse は 2X-Small が 1 つ。job の同時実行は 5 task まで。fair usage を超えるとその日は compute が停止する。非商用限定。長期間使わない account は削除されうる。外向きの通信は信頼済み domain に限られる (Oura や Todoist の API を Databricks の中から叩けるかに影響する)。storage の上限は記載なし (page の更新日 2026-11-16) | ローカルからの SQL 接続と MCP 接続の可否 (page に記載なし) |
| BigQuery sandbox | credit card なしで月 1 TB の query と 10 GB の storage。billing を有効にすると同じ無料枠のまま table が永続化する (第三者の記事による) | table の 60 日有効期限と DML 不可の制約は古い Google の資料にもとづく |
| Snowflake | 30 日 trial ($400 分) のみで、恒久的な無料枠はない | — |
| MotherDuck | 無料枠がある (10 GB + compute 時間の制限) という情報と、2025 年の Free Plan の記述が食い違う | 現行の料金体系 |

### ingestion の軸と、データソース側の制約

| データソース | 分かったこと | 検証の程度 |
|---|---|---|
| Oura | Personal Access Token は deprecated で、OAuth2 が正式な方法。server-side flow の refresh token は使い捨てで、毎回新しいものを保存する必要がある。API request には `User-Agent` header が必須 | 公式 page は PAT に "[Deprecated]" と表示しているだけ。2025 年 12 月廃止という日付は OpenAPI spec と第三者情報 (検索結果の要約) による。membership 必須という話は第三者情報で未確認 |
| MoneyForward ME | 公式の個人向け API は見つからなかった。家計簿 CSV は月単位でしか出力できない。期間を指定して一括取得する bookmarklet は非公式で、規約上の risk がある。2026-09-17 の規約改定で ChatGPT Apps 連携が追加された | 検索結果の要約にもとづく。Claude 向けの連携があるかは未確認 |
| Suunto (D5) | Suunto アプリの JSON export は FIT より情報が多い (forum の報告)。`divejson` package が Suunto JSON の mapping を持つ | D5 に特化した parser は確認できなかった |
| Todoist | API v1 で REST と Sync が統合された。旧 Sync v9 / REST v2 は 2026-02-10 に終了。v1 に completed tasks 系の endpoint (by completion date / by due date) がある。personal API token が使える | endpoint の parameter と期間の制限は未確認 (公式 docs の先頭 10 万字しか読んでいない) |
| 健康診断 | 手動入力 | — |
| 取り込み手段 | dlt (`dlt init rest_api duckdb`。既定は追記なので merge / replace の設定が必要)、手書き script (`*-to-sqlite` 型、HPI 型)、Airbyte (Oura connector あり) | dlt と Airbyte の個人規模での運用負荷は未確認 |

### MCP 接続

| 選択肢 | 分かったこと | 未確認 |
|---|---|---|
| `mcp-server-motherduck` | MotherDuck の account なしでローカル DuckDB に接続できる。既定は read-only で、read-only 接続は file lock を取らない。Claude Desktop / Claude Code に対応。README は「read-only mode だけでは第三者アクセスに不十分」と明記している (ローカルの filesystem へのアクセスや設定変更は可能なまま) | DuckLake への対応 |
| `mcp-server-duckdb` (ktanaka101) | `--readonly` flag あり | 保守状況 |
| SQLite 系 MCP / Datasette | 今回の検索では明確な候補が出なかった | 未調査 |
| ローカル LLM (Ollama など) を MCP client 側の model にする | 単純な tool 呼び出しなら実用になる。複数 step の複雑な tool 呼び出しでは cloud model に劣る。Docker の評価では Qwen 3 (8B / 14B) が local model の中では最も正確だった。SQL の精度に関する公開 benchmark は見つからなかった。Saubury の報告では「とても遅い」 | 本人の machine での実用性 |
| cloud LLM を使いつつ流出経路を絞る | Claude Code の sandbox と permission で外への通信を制限できる。ただし sandbox が効くのは Bash だけで、WebFetch / MCP は別に設定が要る。設定どうしが干渉するという issue の報告もある | 設定が意図どおりに効くかの検証 |

## 出発点からの認識の変化

- 変わった点:
  - security の主な境界は storage の暗号化ではなく、**LLM (MCP client) にデータを渡す経路** にある。cloud LLM を使う限り、query 結果は外に出る。lethal trifecta の 3 条件が Claude Code の利用形態で揃いうる。
  - ingestion の制約 (Oura の OAuth2 化、MoneyForward に API がないこと) は、storage や engine の選定より運用の手間に強く効く可能性がある。
  - 「warehouse を作らない」系統 (HPI 型、データソースごとの MCP 型、データソースの公式 MCP を直接使う型) が、実在する選択肢として見えた。
  - (2 ラウンド目) 個人データ基盤の典型的な失敗は、技術選定ではなく「集めたが使わない」ことにある。記録するものが多すぎることと、問いがないこと。requirement.md は「何を集めるか」から書かれていて、「何に答えたいか」が書かれていない。
  - (2 ラウンド目) 「cloud に置かない = 安全」は成り立たない。cloud LLM を使えば、query 結果は Anthropic に渡り、opt-in 次第では 5 年保持される。逆に、GitHub Actions や managed Postgres のように cloud を使うほうが、手元の machine の sleep や運用負荷の問題を減らせる面もある。
- 変わらなかった点: 個人規模ではローカルの単一ファイル DB で足りるという見立て。実践者の事例もこの方向に寄っていた。ただし、エージェントが選んだ検索の切り口の範囲での結論である。
- 否定できた思い込み: 「storage を暗号化してクラウドに暗号文しか置かなければプライバシーは守られる」。LLM 経由の流出経路はこれとは別にある。
- 本人の回答 (2026-11-21):
  - 問いが先に要るという点には同意する。ただし本人は、データが集まること自体に喜びを感じるタイプでもある。また、各種データを手元に置いて自由に可視化できるようになることにも魅力を感じている。つまり、「集めること」と「自由に可視化できること」はそれ自体が目的の一部であり、「使わないなら失敗」という QS 研究の評価軸はそのままでは当てはまらない。
  - security の境界が LLM 側にあるという点には同意する。ただし、LLM にデータを渡すことにはそれほど risk を感じていない。認証情報を渡すわけではないからである。守る対象の重心は、データの中身より **認証情報** (各データソースの token など) にある。
  - 基盤は作るほうがよい。基盤を作らない系統 (HPI 型、公式 MCP を直接使う型) は、主な選択肢としては採らない見込み。
  - 4 (cloud への見方) と 5 (業務経験の移植) については回答なし。

## 分かっていないこと

- この基盤で答えたい問い (例: 睡眠と飲酒の関係、支出の推移、ダイビングの記録)。データソースごとに 1 つずつでも挙げられるか。本人にとっては「集めること」と「自由に可視化できること」も目的に含まれるので、問いがなくても成立する部分と、問いが要る部分を分けて考える
- 可視化の自由度に対する要求 (BI tool、notebook、LLM による生成のどれが合うか)。本人は当初 BI tool を主に考えていたが、Claude で dashboard を生成する手段 (Claude Dashboards のようなもの) も候補に挙がった (本人コメント、2026-11-21)。その場合、dashboard とデータが claude.ai 上に置かれるのか、手元に閉じるのかは未確認
- 認証情報 (Oura の OAuth refresh token、Todoist の token、cloud の API key など) の保管。本人の方針は「基本はローカル PC 上に置き、git には入れない。または都度本人がログインする」(本人コメント、2026-11-21)。具体的な仕組み (`.env`、OS の keychain、password manager など) と、定期実行との両立 (都度ログインでは自動化できない) は未確定。GitHub Actions で取り込みを定期実行する場合は、GitHub の secrets で管理する案もある (本人コメント、2026-11-21)。その場合に確認が要る点は次のとおり。
  - 認証情報を GitHub (第三者の cloud) に預けることになる。「ローカル PC に置く」という基本方針の例外として扱うか
  - Oura の refresh token は 1 回しか使えないので、実行のたびに新しい token を保存し直す必要がある。workflow から secrets を更新するには、secrets の書き込み権限を持つ別の token が要るとみられる (未確認)
  - 取り込んだデータが GitHub の runner を通る。repo に commit すれば git の履歴にも残る。private repo では Actions の無料枠に上限がある
- MCP の結果が Anthropic の保持の対象になるか。本人は training opt-in を設定していない (本人コメント、2026-11-21)。opt-in していない場合の保持期間は 30 日という報道がある (2025-08 の consumer terms 更新時)。ただし現行の policy での確認はしていない。本人はこの risk を低く見ている
- threat model: 何を (健康・家計・健診のどれを)、誰から (cloud の provider、LLM provider、prompt injection、端末の盗難) 守るのか
- MCP 経由で cloud LLM に渡してよいデータの範囲。ローカル LLM を使う必要があるか
- 各データソースの更新頻度と、手作業 (MoneyForward の月次 CSV、Suunto の export) をどこまで許容するか
- BI (dashboard) が本当に必要か。LLM との対話で足りるか
- データ量の実測値
- 業務の基盤で「うまくいった理由」と「捨てた選択肢」(本人に未確認)
- 運用の手間の許容量 (月に何分までか)

## 深追いしなかったもの

| リソース | なぜ深追いしなかったか |
|---|---|
| dev.to の wellallytech / beck_moulton 系の記事群 (DuckDB + dbt / Evidence / Superset / Grafana / Streamlit で Quantified Self) | 似た内容の記事が量産されており、宣伝色が強く質が低い。系統 C の存在を確認するにとどめた |
| Simon Aubury「My (very) personal data warehouse」(Fitbit × DuckDB) | 系統 C の事例。Aubury の新しい記事 (MCP) を優先した |
| apple-health-mcp、goetta-finance、Quicken MCP、bibekg/mydata | 系統 D の存在確認にとどめた |
| Fivetran「Run local AI queries on your data lake with DuckDB and Claude」(2026-04) | 業務データの例で、個人データではない |
| Airbyte (Oura → DuckDB / BigQuery) | vendor の記事で、広告に近い |
| TDWI「Personal Data Warehouse」(2007) | 名前は同じだが、企業内の個人向け DWH の話で文脈が違う |
| homelab dashboard 系 (AMUD Dashboard など) | 「SQLite にすると運用が楽」という傍証にとどまる |
| MoneyForward の bookmarklet 記事、Muse 経由の CSV 作成の体験談 | 非公式の手段。規約の確認が先 |
| Talk Python #299 | 時間箱の都合 |
| Supabase / Neon の公式料金 page | 第三者の比較記事で概要をつかむにとどめた。容量の数字は食い違っている |
| ローカル LLM の tool calling 評価 (Docker blog、ChatForest など) | 検索結果の要約だけ。本人の環境で試すほうが早い |
| Claude Code の sandbox 設定の GitHub issue 群 | 実装の詳細。採用が決まってから検証すればよい |
| MIT Technology Review「My so-called quantified life」(2012) ほか QS 撤退記事 | Choe 2014 と Gordon Bell で論点を代表させた |

## 出典

- https://simonwillison.net/2020/Nov/14/personal-data-warehouses/ (2020-11-14)
- https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/ (2025-06-16)
- https://github.com/karlicoss/HPI (日付不明)
- https://dev.to/saubury/i-dont-need-an-untrusted-llm-to-tell-me-im-spending-too-much-on-coffee-57kn (年不明、5 月 14 日)
- https://dev.to/saubury/my-very-personal-data-warehouse-fitbit-activity-analysis-with-duckdb-426l (日付不明)
- https://github.com/motherduckdb/mcp-server-motherduck (日付不明)
- https://pypi.org/project/mcp-server-duckdb/ (日付不明)
- https://github.com/neiltron/apple-health-mcp (日付不明)
- https://pypi.org/project/goetta-finance/ (日付不明)
- https://docs.databricks.com/aws/en/getting-started/free-edition-limitations (2026-11-16 更新)
- https://cloud.google.com/bigquery/docs/sandbox (日付不明)
- https://cloud.google.com/blog/products/data-analytics/query-without-a-credit-card-introducing-bigquery-sandbox (日付不明、古い記事)
- https://docs.snowflake.com/en/user-guide/admin-trial-account (日付不明)
- https://motherduck.com/trial-feb-2025-pricing-update (2025-02)
- https://cloud.ouraring.com/docs/authentication (日付不明)
- https://developer.todoist.com/api/v1/ (日付不明)
- https://groups.google.com/a/doist.com/g/todoist-api/c/brwENjfT_tk (Sync v9 / REST v2 の終了告知、日付不明)
- https://support.me.moneyforward.com/hc/ja/articles/62305163699993 (2026-09-17 改定)
- https://forum.suunto.com/post/159282 (日付不明)
- https://pypi.org/project/divejson/ (日付不明)
- https://dlthub.com/docs/tutorial/rest-api (日付不明)
- https://posthog.com/blog/why-you-should-use-a-data-warehouse (日付不明)
- https://www.fivetran.com/blog/run-local-ai-queries-on-your-data-lake-with-duckdb-and-claude (2026-04)
- http://dx.doi.org/10.1145/2556288.2557372 (Choe et al., CHI 2014)
- https://www.technologyreview.com/2016/04/19/160909/life-logging-is-dead-long-live-life-logging/ (2016-04-19)
- https://privacy.claude.com/en/articles/10301952-updates-to-our-privacy-policy (2026-06-08 掲載、2026-07-08 施行)
- https://www.anthropic.com/news/updates-to-our-consumer-terms (2025-08-28)
- https://www.todoist.com/help/articles/use-claude-with-todoist-connector-ANlg7v13q (日付不明)
- https://www.todoist.com/help/articles/using-todoist-mcp-with-claude-code (日付不明)
- https://simonwillison.net/2020/Oct/9/git-scraping/ (2020-10-09)
- https://jerrynsh.com/how-i-saved-scraped-data-in-an-sqlite-database-on-github (日付不明)
- https://supabase.com/kb/faqs/platform/free-project-pausing (日付不明)
- https://neon.com/guides/neon-vs-supabase-free-plan (日付不明、vendor 自身の比較記事)
- https://www.docker.com/blog/local-llm-tool-calling-a-practical-evaluation/ (日付不明)
- https://code.claude.com/docs/en/sandboxing (日付不明)
- https://code.claude.com/docs/en/permissions (日付不明)
- 以前の調査: https://claude.ai/artifact/AgKwjcoBMNNtXEKNaaE1JF (2026-11-21 時点で読んだ版。中の事実は今回未検証)
