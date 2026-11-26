# 探究: agent harness の方針

| 項目 | 内容 |
|---|---|
| 戦略名 | dozou の agent harness の方針 |
| ステータス | レビュー中 |
| 作成日 | 2026-11-25 |
| 最終更新日 | 2026-11-25 |
| 質問の窓口 | soonraah (本人) |

## 探究のスコープ

- この戦略で決めること: dozou の開発を Claude Code が人間の介入を最小限にして自立的に進められるよう、どんな harness をどの順で育てていくかの大枠。要件は [requirement.md](requirement.md)。
- 探究の重心: 社外寄り。組織は本人 1 人である。「社内の前例」に当たるのは、本人が業務で作っている Claude Code の harness と、dozou で既に使っている superpowers plugin だけである。
- 時間箱: 最小 2 時間 / 最大 4 時間 (前回の探究と同じ)。実績は 3 ラウンドで、Web 検索 7 本、深掘り 19 ページ (subagent 経由で取得)。3 ラウンド目は、本人が追加した資料を読んだ。実際にかかった時間は計測していない。
- 深掘り対象は、時間箱の都合でエージェントが選んだ。入れ替えは可能。検索クエリも、事前にユーザーと合意せずにエージェントが決めた。

## 要約

Claude Code 向けの harness には、大きく 8 つの選択肢があった。

- A: [walkinglabs](https://walkinglabs.github.io/learn-harness-engineering/ja/) の部品を最初から揃える。
- B: 最小セットから始め、失敗に応じて足し、効かないものは外す。
- C: [superpowers](../../superpowers/) を主軸にして、repo 側は薄くする。
- D: `/goal` のような [Claude Code 組み込みの loop](https://code.claude.com/docs/ja/goal) を使う。
- E: クラウドで無人実行する。
- F: dbt や dlt 向けに領域特化した検証を持つ。
- G: 複数の agent を graph として orchestration する。
- H: lint やテストのような決定論的な sensor を先に揃える。

これらは互いに排他ではなく、組み合わせて使うものである。概念の整理には、[Fowler (Böckeler)](https://martinfowler.com/articles/harness-engineering.html) の分類が使いやすい。行動の前に誘導する guides と行動の後に検査する sensors、決定論的な computational と LLM が判定する inferential、という 2 つの軸である。

似た状況の組織は、harness を「育てる」方向で運用していた。[HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents) は、理想の構成を事前に設計して失敗し、作った hook の大半を捨てた。[Anthropic](https://www.anthropic.com/engineering/harness-design-long-running-apps) は部品を 1 つずつ外して、どれが効いているかを確かめ、evaluator は「タスクがモデル単体の能力を超えるときだけコストに見合う」とした。[OpenAI](https://openai.com/index/harness-engineering/) は、AGENTS.md を目次として使い、不変条件を custom lint で強制した。ただし、自分たちの成果は同等の投資なしには一般化できないとも書いている。個人開発の [thoughtbot](https://thoughtbot.com/blog/creating-software-while-afk-with-github-workflows) は、GitHub Actions と label だけの軽い構成で進めていた。データ領域の [dbt Wizard](https://docs.getdbt.com/blog/wizard-agent-harness) は、検証を「数字が意図どおりか」で行う。その理由は、黙って誤った数字を出す欠陥が、見つかるまで中央値 65 日かかったことにある。context file の効果については、[ETH の研究](https://infoq.com/news/2026/03/agents-context-file-value-review/)が、成功率は改善せず推論コストが 20% 以上増えたと報告している。

出発点は「A の部品をある程度揃える」だった。探究の後、本人は「B のように最小から始めて育てる進め方でもよい」と考えるようになった。walkinglabs 自身も、最初は 4 ファイルだけ置き、残りは必要になってから足すことを勧めている。さらに、その例は web app 向けで、データ基盤で何が E2E に当たるかは扱っていない。業務の harness (superpowers を薄く wrap した skill と、index として使う CLAUDE.md) は dozou に持ち込める。ただし、業務の harness は既存の CI/CD と staging という sensor の上に乗っていて、dozou にはそれがない。C、D、F、G、H もいずれは入れたいが、最初にすべてを揃えるのは難しい。

分かっていないことは次のとおりである。

- dozou の開発で、agent が実際にどこで止まり、どこで失敗するか。失敗のデータはまだない。
- dozou で「E2E」に当たる検証をどう定義するか。
- 自立性の目標水準。1 task を完走できれば十分か、それ以上を求めるか。
- 業務の harness でサポートできていない部分は何か。
- セキュリティ制約を戻す時期。

これらは診断で確かめる。

## 出発点の見立て (探究前)

- 最有力だと思っていたアプローチ: [Learn Harness Engineering](https://walkinglabs.github.io/learn-harness-engineering/ja/) (walkinglabs) の構成をそのまま踏襲する。
- そう考えた根拠: requirement.md が、このサイトの内容をベースにすると明記している。それ以上の根拠は聞いていない。
- 過去に似た問題を解いた経験: 業務で、Databricks 上のデータ基盤 (dbt / terraform) の開発を Claude Code で行っている。harness は約 3 か月前から導入し、superpowers を中心に自動化しているが、すべてをカバーできてはいない (詳細は「社内の前例」)。

### 過去の経験は今も有効か

| 観点 | 当時 (業務) | 現在 (dozou) | 差が効くか |
|---|---|---|---|
| 時期 | 2026-08 頃から現在まで (約 3 か月) | 2026-11 | 小さい |
| 組織規模・チーム構成 | 開発チームは 5 人。harness の開発はほぼ本人 1 人 | 本人 1 人 | 小さい。harness を作るのが本人 1 人という点は同じ。ただし業務では、harness を使う人が 5 人いる |
| トラフィック / データ量 / 顧客数 | TB 級 ([前回の探究](../personal-data-platform/01-exploration.md)) | 個人データ (小) | 検証の重さが変わる。小さいデータなら、実データで丸ごと検証するのも現実的になりうる (未確認) |
| 使えた基盤・マネージドサービス | Databricks、GitHub Actions による CI/CD (harness 導入前からある。terraform validate / TFLint / OPA、SQLFluff、dbt-osmosis、Flake8 / Black、unit test、staging での検証)。[出典](https://soonraah.github.io/posts/ordinary-data-platform-migration-part-5/) (2025-09-18) | 常時起動でない Mac 1 台。NAS やサーバはない。CI は pre-commit のみ (main 時点) | **大きい**。業務の harness は、既存の CI/CD という sensor の上に乗っている。dozou にはそれがない |
| 制約 (規制・コスト・締切) | 業務上の review 体制 (詳細不明) | 運用は月 1 時間以内。個人の subscription。クラウドでの無人実行は今のところ考えていない | 不明 |
| うまくいった理由 | 未確認。今回は聞いていない | — | — |

判定: 一部しか成立しない。superpowers を薄く wrap する構成と、index として使う CLAUDE.md は持ち込める。一方で、業務の harness が前提にしている CI/CD と staging 環境は dozou にはない。

## 社内の前例

### 業務の Claude Code harness (Databricks / dbt / terraform)

- 時期・規模: 導入は約 3 か月前。開発チームは 5 人で、harness の開発はほぼ本人 1 人が担っている。
- 課題: dbt と terraform の project 開発の自動化
- 採ったアプローチ: hooks、rules、skills、docs で構成している。
  - 開発の中心は、superpowers を薄く wrap し、project ごとの仕様を載せた skill である。
  - ほかに、dbt modeling の rule、PR review 用の skill、commit message と branch 名の rule などがある。
  - CLAUDE.md は、ほかのドキュメントへの index として書いている。
  - CI/CD は harness より前からある (GitHub Actions。terraform validate / TFLint / OPA / SQLFluff / dbt-osmosis / lint / unit test。PR の review 前に staging での検証を義務付けている)。
- 捨てたアプローチ: 今回は聞いていない
- 判断の背後にあった考え方: 今回は聞いていない。外から見える範囲では、ワークフローを自作せず superpowers に任せ、project 固有の知識だけを上に載せる構成になっている。
- その後どうなったか: 「すべてをサポートできているわけではない」。具体的に何が足りないかは今回は聞いていない。
- 保守されている状態か: 本人が保守している。superpowers 本体は第三者が保守している。
- 参照: [ふつうのデータ基盤移行 Part 5. IaC と CI/CD 編](https://soonraah.github.io/posts/ordinary-data-platform-migration-part-5/) (2025-09-18)。harness 自体は社外秘

### dozou の既存の仕組み

- superpowers plugin が有効になっている (`.claude/settings.json`)。実際に [docs/superpowers/specs/](../../superpowers/specs/) と [docs/superpowers/plans/](../../superpowers/plans/) に、spec と plan が 1 件ずつある。
- pre-commit hooks (commit message、Python、markdown) と PR template が main に入っている。
- **保守者がいるという観点**: superpowers は第三者が保守していて、本人が業務でも使っている。「すでに実装されていて保守する人がいる」という条件を満たす唯一の harness 部品である。
- `chore/claude-code-security` branch: requirement.md の指示どおり、内容は参照していない。現在の作業ツリーにある `.claude/settings.json` (sandbox 有効、`*.github.com` の通信を拒否、bypass mode を無効化、settings の編集を拒否) も、本人に確認したところ「いったん無視する」セキュリティ作業の一部だった。したがって、この探究の選択肢の成立条件には含めない。

## 業界の事例

### Anthropic: Effective harnesses for long-running agents

- 自社との距離: 最先端企業 (前提が違う)。full-stack web app の demo である。
- 時期・規模: 2025-11-26。Opus 4.5。claude.ai の clone で、機能は 200 以上
- 課題: context window をまたぐと記憶が消える。一度に全部作ろうとして途中で context が尽きる。後半で「完了」と早まって宣言する。
- 採ったアプローチ: initializer agent と coding agent の 2 段構成。initializer は `init.sh`、`claude-progress.txt`、最初の commit、機能一覧の JSON (すべて `passes: false`) を作る。coding agent は 1 回に 1 機能だけ進め、clean state で終える。テストは Puppeteer MCP を使ったブラウザ上の E2E で行う。
- 捨てたアプローチ: compaction だけに頼る方式 (不十分だった)。機能一覧を Markdown で持つ方式 (モデルが壊しやすい)。unit test と curl だけで検証する方式 (E2E の不具合に気づけなかった)。
- 判断の背後にあった考え方: session をまたぐ状態は repo 内のファイルと git に外部化する。完了したかどうかは、モデルの自己申告ではなく検証で決める。
- 結果: 定量値は公開されていない。ブラウザ自動化で「大幅に改善した」と定性的に書かれているだけである。
- この情報源が語っていないと思われること: コスト、試行回数、harness の保守負荷。web app 以外への一般化。
- 出典: <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents> (2025-11-26)

### Anthropic: Harness design for long-running application development

- 自社との距離: 最先端企業 (前提が違う)
- 時期・規模: 2026-03-24。Opus 4.5 / 4.6
- 課題: 前の記事の harness が頭打ちになった。context anxiety と、自分の成果を甘く評価する自己評価の甘さがあった。
- 採ったアプローチ: planner / generator / evaluator の 3 agent。実装前に sprint contract で完了の定義を合意する。evaluator は Playwright で採点し、hard threshold を設ける。
- 捨てたアプローチ: harness を一度に大きく削る簡素化 (性能を再現できず、どの部品が効いているのか分からなくなった。以後は 1 部品ずつ外す方式に変えた)。Opus 4.6 では sprint 構造を外した。evaluator は sprint ごとではなく最後に 1 回だけにした。
- 判断の背後にあった考え方: evaluator は固定の部品ではない。タスクがモデル単体の能力を超えるときだけ、コストに見合う。harness の部品は、モデルが改善すると不要になりうる。
- 結果: レトロゲームメーカーでは、solo 実行が 20 分 / $9、full harness が 6 時間 / $200 だった。DAW は 3 時間 50 分 / $124.70。
- この情報源が語っていないと思われること: 試行のばらつき (結果は単発の実行に見える)。evaluator を調整し続ける保守コスト。
- 出典: <https://www.anthropic.com/engineering/harness-design-long-running-apps> (2026-03-24)

### OpenAI: Harness engineering (Codex)

- 自社との距離: 最先端企業 (前提が違う)。3〜7 人のチームで、PR は 1 日あたり数十件
- 時期・規模: 2026-02-11。約 5 か月で約 100 万行、約 1,500 PR
- 課題: 人間が手でコードを書かずに製品を作る。初期の遅さの原因は、モデルではなく環境の仕様不足だった。
- 採ったアプローチ: repo を system of record にする。`AGENTS.md` は約 100 行の目次にして、詳細は `docs/` に置く。docs の鮮度は linter と CI で検査する。層構造の依存方向を custom lint で強制し、lint のエラーメッセージに修正手順を書く。background の cleanup agent に golden principles を適用させる。agent 同士でレビューする。
- 捨てたアプローチ: 巨大な AGENTS.md 1 つで済ませる方式。毎週金曜に人手で「AI slop」を掃除する方式 (スケールしなかった)。
- 判断の背後にあった考え方: 「Humans steer. Agents execute.」。人間の QA がボトルネックになるので、機械で検証できる不変条件に置き換える。
- 結果: 本人たちの推定では、手書きの約 1/10 の時間で済んだ。根拠の詳細は書かれていない。
- この情報源が語っていないと思われること: token 費用。harness の構築と保守にかかった工数。品質指標。記事自身が「同等の投資なしには一般化できない」と書き、最小限の merge gate は「低スループットの環境では無責任」と明記している。
- 出典: <https://openai.com/index/harness-engineering/> (2026-02-11)

### thoughtbot (Fritz Meissner): 個人の副業を GitHub Actions + Claude Code で進める

- 自社との距離: **自社に似た規模・制約** (個人、スマホから 1 日 10 分程度)
- 時期・規模: 2026-05-04。個人の Next.js アプリ
- 課題: 本人が作業できる時間がほとんどない状態で開発を進める。
- 採ったアプローチ: `anthropics/claude-code-action` を使う。label で段階を進める (`needs-elaboration` で計画、`ready-for-dev` で実装と PR 作成、`agent-review` で指摘を反映して再実装)。確認は Vercel の preview で目で見る。起動は `--max-turns 20 --dangerously-skip-permissions`。
- 捨てたアプローチ: 記述なし。CLAUDE.md、hooks、進捗ファイルへの言及もない。
- 判断の背後にあった考え方: コード品質より進捗を優先する。著者はコードを読まない。
- 結果: テストは 0 件から 500 件以上、coverage は 77% になった。過去 1 か月の進み具合が以前の 7 か月分を上回った (本人の主張で、計測根拠は示されていない)。費用は月 $20 (Claude Pro) + $10 (GitHub Pro)。
- この情報源が語っていないと思われること: 保守性とセキュリティの扱い。業務水準との差 (本人は「serious gaps」があると認めているが、具体的には書いていない)。
- 出典: <https://thoughtbot.com/blog/creating-software-while-afk-with-github-workflows> (2026-05-04)

### HumanLayer: Skill Issue — Harness Engineering for Coding Agents

- 自社との距離: 中間。harness を製品として提供している企業で、brownfield の企業コードベースが対象
- 時期・規模: 2026-03-12。数十のプロジェクトと数百の session
- 課題: coding agent の出力品質を、モデルではなく設定で上げる。
- 採ったアプローチ: CLAUDE.md は 60 行未満。skills で段階的に開示する。MCP は自作の薄い CLI に置き換える。Stop hook で型チェックと lint を走らせ、成功時は何も出さず、失敗時だけエラーを返す。subagent は context を分けるために使う。
- 捨てたアプローチ: 理想の構成を事前に設計すること。「念のため」で skills や MCP を足すこと。session の終わりに 5 分以上かかるテストスイート全体を走らせること。subagent ごとにツールの権限を細かく制御すること。作ったうちの大半の hook も捨てた。
- 判断の背後にあった考え方: 実際に失敗が起きてから harness に足す。context を消費するもの (ツール定義やテスト出力) は削る。
- 結果: 定量値は公開されていない。
- この情報源が語っていないと思われること: hook と CLI の保守負荷。自社製品へ誘導する立場からの記事であること。
- 出典: <https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents> (2026-03-12)

### dbt Labs: Wizard agent harness

- 自社との距離: **同じ領域** (dbt によるデータ開発)。ただし vendor の製品である。
- 時期・規模: 2026-10-14。著者の個人 platform で 24,388 run、merge された PR は 405 件
- 課題: MCP と skills だけでは、手順に毎回従わせることも、変更後の data diff を見せることもできない。
- 採ったアプローチ: dbt のコマンドを shell ではなく専用のツール経由で実行する (deferral を自動で効かせ、検証範囲を限定する)。ツールの出力は失敗した node だけに絞る (約 150 token。通常の出力は約 1,300 token)。subagent は explorer / worker / validation / test_writer に分ける。レビューでは impact analysis、SQL diff、dev と prod の data diff を見せる。破壊的なコマンドには常に承認を求める。
- 捨てたアプローチ: shell や MCP 経由で dbt を実行する方式 (開発 schema 全体を build してしまうことがあった)。
- 判断の背後にあった考え方: データの仕事はコードを書くだけでは終わらない。検証は「コンパイルが通る」ではなく「数字が変わっていない、または意図どおりに変わった」で行う。
- 結果: 明示的なエラーは中央値 1 日で見つかった。一方、黙って誤った数字を出す欠陥は、見つかるまで中央値 65 日 (最長 361 日) かかった。agent が作った PR の約 90% が初回の CI を通った。
- この情報源が語っていないと思われること: vendor の製品紹介を兼ねていること。比較に使ったモデルや harness の条件。
- 出典: <https://docs.getdbt.com/blog/wizard-agent-harness> (2026-10-14)

## 論文・書籍・講演

| 資料 | 種類 | 公開日 | ここから得たこと | リンク |
|---|---|---|---|---|
| Harness engineering for coding agent users (Birgitta Böckeler, martinfowler.com) | 記事 | 2026-04-02 | harness を 2 つの軸で分類している。1 つは guides (事前に行動を誘導する) と sensors (行動の後に観測する)、もう 1 つは computational (決定論的で速い) と inferential (LLM による判定で、遅く非決定的) である。規制の対象は maintainability、architecture fitness、behaviour の 3 種類で、behaviour は「未解決」としている。速い検査は commit の前に、遅い検査は統合の後に置く (keep quality left)。同じ問題が繰り返し起きたら、制御を改善する (steering loop)。目的は人間の入力をなくすことではなく、重要な場所に向けることだとしている。未解決の問いとして、「sensor が発火しないのは品質が高いからか、検出できていないからか」を挙げている | <https://martinfowler.com/articles/harness-engineering.html> |
| What is an agent harness? (Parallel) | 記事 (vendor) | 日付不明 | harness は、モデル以外のすべて (ツール、メモリ、コンテキスト、計画、検証) を担う層である。framework (部品) や orchestrator (制御フロー) とは区別している。harness を最小限にすべきか作り込むべきかについては、主張していない | <https://parallel.ai/articles/what-is-an-agent-harness> |
| Learn Harness Engineering (walkinglabs) 講義 01〜14 | 講義サイト | 日付不明 (著者も表示なし) | 後述の「walkinglabs の構成」 | <https://walkinglabs.github.io/learn-harness-engineering/ja/> |
| 同 Harness 設計: Claude Code | 記事 | 日付不明 | Claude Code 自体が、階層化したメモリ、compaction、hooks、subagent を備えた harness である。参考にしたい点として「完了宣言の防止は prompt で頼まず hooks で強制する」を挙げている。記述の一部は第三者 (VILA Lab) のソースコード分析に依拠している | <https://walkinglabs.github.io/learn-harness-engineering/ja/harness-designs/claude-code/> |
| Building always-on agents (William Hu) | 記事 | 2026-11-13 | event inbox、timers、memory、permissions、outbox の 5 つの primitive。memory には再調査できない情報だけを置き、ほかは pointer で持つ。permission が最もリスクの高い部分である。通知は最初は控えめにする | <https://claude.com/ja/resources/articles/building-always-on-agents> |
| Evaluating AGENTS.md (Gloaguen et al., ETH Zurich) | 論文 (ICLR 2026) | 2026 | context file を置いても成功率は改善せず、推論コストは 20% 以上増えた。人が書いた file は約 4% 改善したが、LLM が生成した file は約 3% 悪化した。人が書く要件は最小限にするよう勧めている | <https://iclr.cc/virtual/2026/10018749>、<https://infoq.com/news/2026/03/agents-context-file-value-review/> (2026-03-06) |
| Lulla et al. | 論文 | 2026 | AGENTS.md があると、実行時間の中央値が 28.6% 短くなり、出力 token が 16.6% 減った。効率を測った研究で、正しさは測っていない | <https://arxiv.org/html/2601.20404v2> |
| Claude Code `/goal` | 公式ドキュメント | 日付不明 | 完了条件を満たすまでターンを自動で続ける。評価には小型のモデルを使い、会話しか読まない (ファイルもコマンドも見ない)。無人で動かすには auto mode と組み合わせる。`-p` でも動く | <https://code.claude.com/docs/ja/goal> |
| Claude Code スケジュールタスク (旧称ルーティン) | 公式ドキュメント | 日付不明 (research preview) | Anthropic のクラウドで動くので、Mac を閉じていても実行される。毎回 repo を clone して `claude/` branch に push する。GitHub との接続が必要。auto 権限で始まる。間隔は 1 時間以上 | <https://code.claude.com/docs/ja/routines> |
| Claude Code GitHub Actions | 公式ドキュメント | 日付不明 | GitHub-hosted runner の分数を消費する | <https://code.claude.com/docs/en/github-actions> |

### walkinglabs の構成 (出発点の見立ての中身)

- 講義 01〜12 は、1 session を信頼できるものにするための部品を扱う。
  - harness は「指示・ツール・環境・状態・フィードバック」の 5 subsystem からなる (講義 02)。
  - 中心は repo を system of record にすること (03)。入口の `AGENTS.md` / `CLAUDE.md` は短い目次にして、詳細は topic 文書に分ける (04)。
  - session をまたぐ状態は `PROGRESS.md` と `DECISIONS.md` に残す (05)。初期化は独立した phase にする (06)。
  - 作業中の task は常に 1 つ (WIP=1) にする (07)。機能一覧は状態機械として持ち、検証が通らない限り passing にしない (08)。
  - 完了判定は 3 層の検証で外部化する (09)。E2E と、アーキテクチャ規則を実行可能にした検査を使う (10)。
  - 実行時の観測性を持たせる (11)。session の終わりに clean state を確認し、月に 1 回 harness を簡素化する (12)。
- 最初にコピーする 4 ファイルは、`CLAUDE.md`、`init.sh`、`claude-progress.md`、`feature_list.json`。残りは必要になってから足す (テンプレートページ)。
- 講義 13 (loop) は、成熟度を 5 段階のはしごにしている。ゴールランナー (`/goal`)、スケジュールされた単一タスク、Maker/Checker の分離、自走ループ、フリートの順である。そのうえで「すべてのループにすべてが必要ではない」「レベル 1 が最速」と書いている。ループの静かなコストとして、検証の借金、理解の腐敗、認知的降伏、token の爆発を挙げている。
- 講義 14 (graph) は、使ってよい条件を 5 つ挙げ、満たすのが 3 つ未満ならワークフロースクリプトで足りるとしている。
- **このサイトが語っていないこと**:
  - 著者と日付が表示されていない。
  - 講義同士で食い違いがある。入口ファイルの推奨行数は 100 行・50〜100 行・50〜200 行の 3 通りあり、進捗ファイル名は `PROGRESS.md` と `claude-progress.md`、機能一覧は `feature_list.json` と `docs/features.md` で揺れている。
  - 講義 10〜12 の数値は、説明用の例か、本文自身が「仮想的」と明記したものである。
  - 例はほぼすべて greenfield の web app (Playwright や Puppeteer による E2E) で、データパイプラインでは何が E2E に当たるかを扱っていない。

## 補足調査: 自律実行に有用な skill / plugin (2026-11-26)

洗練の後に、自律実行に有用な skill と plugin を追加で調べた。
詳細は [research-skills-plugins.md](research-skills-plugins.md) にある。
ここには選択肢の幅を広げるものだけを挙げる。

- superpowers 以外の開発 workflow:
  - feature-dev (Anthropic 公式) は、discovery から summary までの 7 phase を 3 つの subagent (explorer / architect / reviewer) で進める。
  - pstack (cursor/plugins に掲載された個人作者の plugin) は「go deep first」を掲げ、まず 1 agent を信頼できる状態にしてから並列化する。
- loop・並列化・二次意見の実例: cursor の ralph-loop (反復 loop)、orchestrate (planner / worker / verifier)、advisor (重要な判断の前に強い model に相談する)。
- data 基盤向け: dbt Labs 公式の dbt-agent-skills と、dlt の AI harness がある。
- 標準: SKILL.md (Agent Skills)、AGENTS.md、MCP が AAIF (Linux Foundation 配下) にまとまり、特定の tool に依存しない形で整備できる。
- リスク: Snyk の調査 (2026-02 時点、2 registry、3,984 件) では、公開 skill の 13.4% に critical な問題があった。
- 原則: Anthropic (Lance Martin) は、model が良くなったら harness の logic を削るべきだとし、ある model で必要だった context reset が次の model では「dead weight」になった例を挙げている。
- **この調査が語っていないこと**: 個別 plugin の効果は作者や vendor の主張に頼っており、第三者の benchmark は見つかっていない。GitHub への接続が sandbox で拒否されたため、repo の最新状態は直接確認していない。

## 実務担当者から聞いたこと

| 誰に | その人の文脈 | 聞いたこと | 自社との条件の違い |
|---|---|---|---|
| (今回は聞いていない) | — | 本人の判断で、今回は知人への確認を行わない | — |

今回の戦略は、セキュリティや大規模運用のように実務担当者に聞かないと分からない領域には、主に当たらない (requirement.md でセキュリティは除外している)。ただし、ほかの人の harness の「捨てたもの」は公開資料にはほとんど出てこない。この点は弱いまま残る。

## 見つかった選択肢の幅

<!-- 優劣は判定しない。 -->

| 選択肢 | 概要 | 採っている組織 | 成立条件 | 未確認の点 |
|---|---|---|---|---|
| A. walkinglabs をそのまま踏襲 | 講義 01〜12 の部品 (CLAUDE.md、init.sh、進捗ファイル、feature_list.json、3 層検証、clean state) を最初から揃える | walkinglabs (教材)。元になったのは Anthropic の記事 | 「E2E」をデータ基盤で何に置き換えるかを決める必要がある。web app 向けの部品 (ブラウザ E2E など) をそのまま使えない | 個人規模で全部を揃えたときの保守負荷 |
| B. 最小セットから失敗駆動で足す | 短い CLAUDE.md と検証コマンドから始める。失敗が観測されたら hook や文書を足し、効かない部品は 1 つずつ外す | HumanLayer、Anthropic (harness-design)。walkinglabs の講義 02 の段階事例と講義 12 の簡素化も同じ方向 | 失敗を記録して原因を帰属させる習慣が要る | 「足す・外す」をどの頻度で誰が判断するか |
| C. superpowers を主軸にして repo 側は薄くする | brainstorm → spec → plan → 実行 → review の流れは superpowers に任せる。repo には dozou 固有の知識と検証コマンドだけを置く | 本人の業務 (詳細は確認中)。dozou でも既に使っている | superpowers の更新に追従できること。superpowers の前提と dozou の運用が合うこと | 業務で「サポートできていない」部分が何か |
| D. Claude Code 組み込みの loop 機能を使う | `/goal` で完了条件まで自走させる。auto mode と組み合わせる | Claude Code 公式。walkinglabs の講義 13 のレベル 1 | 完了条件を、会話上で示せる形で書ける必要がある (評価モデルはファイルを読まない) | 個人の subscription での使用量 |
| E. クラウドで無人実行する | スケジュールタスクや GitHub Actions で、issue から PR までを無人で進める。人間は PR を確認するだけ | thoughtbot (個人)、OpenAI (チーム)、always-on agents の記事 | GitHub との接続が必要。Mac は常時起動ではないので、ローカル実行は使えない。実データにはクラウドから届かない。**本人は今のところ考えていない** | ローカルにしかない検証 (実データでの dbt build など) を PR の前にどう回すか |
| H. sensor (CI) を先に作る | harness の指示より先に、決定論的な検査 (lint、dbt build / test、data test) を CI か pre-commit に揃える。agent はその結果を見て自分で直す | Fowler (computational sensors、keep quality left)。OpenAI (custom lint)。業務 (CI/CD が harness より前からあった) | 検査をどこで動かすか決める必要がある (ローカルか GitHub Actions か) | 実データを使う検査をどこで実行するか |
| F. 領域特化の検証 harness | dbt や dlt を専用のツールやスクリプト経由で実行し、出力を絞る。data diff を見せる。破壊的なコマンドには承認を求める | dbt Labs (Wizard)。DocuSign (dbt skills + MCP) | dbt と dlt の検証コマンドが決まっていること | 個人のデータ量で data diff を作るコスト |
| G. graph やマルチエージェントの orchestration | 複数の agent をノードにして、共有状態とルーティングで組む | LangGraph 系。walkinglabs の講義 14 | 講義 14 の 5 基準のうち 3 つ以上を満たすこと | — |

A〜G は互いに排他ではない。たとえば「C を軸にして、B の方法で足し、検証には F の考え方を使う」のように組み合わせられる。

## 出発点からの認識の変化

- 変わった点: 出発点は「A (walkinglabs) の部品を最初にある程度揃える」だった。探究を経て、本人は「B のように最小セットから始めて、失敗に応じて足す進め方でもよい」と考えるようになった。きっかけになった事実は次のとおり。
  - walkinglabs のテンプレート自体が「最初は 4 ファイルで、残りは必要になってから」としている。
  - HumanLayer は、理想の構成を事前に設計して失敗し、多くの hook を捨てた。
  - Anthropic は、部品を 1 つずつ外して効果を確かめている。
- 変わらなかった点: C (superpowers 主軸)、D (`/goal`)、H (sensor 先行)、F (領域特化の検証)、G (orchestration) は、いずれも最終的には取り入れたい。ただし、最初の段階ですべてを揃えるのは難しい。この点は探究の前後で変わっていない。どれを先に、どの順で入れるかは、診断と方針のステップで決める。
- 否定できた思い込み: 「walkinglabs をそのまま踏襲する」が、walkinglabs 自身の推奨と一致するとは限らない。walkinglabs は段階的に足すことを勧めている。また、講義の例は web app 向けで、データ基盤の検証 (E2E に当たるもの) は扱っていない。

## 分かっていないこと

- 業務の harness で「サポートできていない部分」が何か。捨てた部品は何か。
- セキュリティ制約をいつ、どの程度戻すか。この探究では外しているが、戻した時点で D (auto mode) や E の成立条件が変わる。
- dozou の開発で、agent が実際にどこで止まっていて、どこで失敗しているか (失敗のデータがまだない)。
- dozou での「E2E」の定義。dlt の取り込みから dbt build、data test、出力の確認まで、どこまでを指すか。
- 自立性の目標水準。1 task を完走できれば十分か。無人で backlog を消化することまで求めるか。
- 個人の subscription で、どれだけの使用量を許容できるか。
- `/goal` の評価モデルの既定値の詳細 (第三者の記事は Haiku だとしているが、公式ドキュメントは「小型高速モデル」としか書いていない)。

## 深追いしなかったもの

| リソース | なぜ深追いしなかったか |
|---|---|
| walkinglabs の harness-designs (Pi / Codex / DeepSeek) | 使う agent が Claude Code に決まっているため |
| Addy Osmani『Loop Engineering』『Orchestration Tax』 | walkinglabs の講義 13 と 14 が要約していたため |
| Snowflake data-eng-bench (<https://www.snowflake.com/en/blog/engineering/data-eng-bench-data-engineering-agent-benchmark/>) | vendor の benchmark で、自社製品が Claude Code に勝ったという主張のため |
| dbt Labs「do coding agents still need dbt skills」 | 時間箱の都合。F の選択肢を深掘りするときの候補 |
| Yurukusa「108 時間の自律運用で集めた 10 個の hooks」(<https://dev.to/yurukusa/10-claude-code-hooks-i-collected-from-108-hours-of-autonomous-operation-now-open-source-5633>) | 時間箱の都合。個人の長時間運用の事例として候補 |
| Zenn の Stop hook による自動開発サイクル (<https://zenn.dev/tettuan/articles/2025-08-54e3b2e1df6dc6>) | 時間箱の都合 |
| levelup.gitconnected「Harness Evolution」 | HTTP 403 で取得できなかった |
| dev.to「72 hours of autonomous Claude Code runs」 | HTTP 404 で取得できなかった |

## 出典

- requirement.md: [requirement.md](requirement.md)
- walkinglabs Learn Harness Engineering: <https://walkinglabs.github.io/learn-harness-engineering/ja/> (日付不明)
- Building always-on agents: <https://claude.com/ja/resources/articles/building-always-on-agents> (2026-11-13)
- Anthropic, Effective harnesses for long-running agents: <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents> (2025-11-26)
- Anthropic, Harness design for long-running application development: <https://www.anthropic.com/engineering/harness-design-long-running-apps> (2026-03-24)
- OpenAI, Harness engineering: <https://openai.com/index/harness-engineering/> (2026-02-11)
- thoughtbot: <https://thoughtbot.com/blog/creating-software-while-afk-with-github-workflows> (2026-05-04)
- HumanLayer: <https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents> (2026-03-12)
- dbt Labs, Wizard agent harness: <https://docs.getdbt.com/blog/wizard-agent-harness> (2026-10-14)
- InfoQ, AGENTS.md research: <https://infoq.com/news/2026/03/agents-context-file-value-review/> (2026-03-06)
- Claude Code `/goal`: <https://code.claude.com/docs/ja/goal> (日付不明)
- Claude Code スケジュールタスク: <https://code.claude.com/docs/ja/routines> (日付不明)
- Claude Code GitHub Actions: <https://code.claude.com/docs/en/github-actions> (日付不明)
- Birgitta Böckeler, Harness engineering for coding agent users: <https://martinfowler.com/articles/harness-engineering.html> (2026-04-02)
- Parallel, What is an agent harness?: <https://parallel.ai/articles/what-is-an-agent-harness> (日付不明)
- soonraah, ふつうのデータ基盤移行 Part 5. IaC と CI/CD 編: <https://soonraah.github.io/posts/ordinary-data-platform-migration-part-5/> (2025-09-18)
- 補足: 本人から示された Anthropic (`/research/harness-design-long-running-apps`) と OpenAI (`/ja-JP/`) の URL は、上の 2 記事と同じ内容として扱った。
