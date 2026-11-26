# 調査: 自律実行に有用な skill / plugin

| 項目 | 内容 |
|---|---|
| 戦略名 | agent-harness |
| 種別 | 補足調査 (deep-research workflow による) |
| 作成日 | 2026-11-26 |
| 前段 | [01-exploration.md](01-exploration.md) |

## 調査の問い

agent の自律実行に有用で、かつ著名な skill や plugin は何か。
例として [pstack](https://github.com/cursor/plugins/tree/main/pstack) を挙げた。

## 調査方法

検索の観点を 6 つに分け、情報源 23 件を取得した。
取得した情報源から主張を 97 件抜き出し、25 件を 3 票の adversarial verification にかけた。
その結果、24 件が残り、1 件が否定された。
残った主張の重複をまとめ、最終的に 11 件にした。

## 要約

自律実行に役立つ有名な skill や plugin は、大きく 2 種類あります。1 つ目は (a) 開発 workflow を手順として固める plugin です。代表は obra/superpowers と Anthropic 公式の feature-dev です。2 つ目は (b) 並列実行や長時間 loop を扱う plugin です。cursor/plugins にある pstack、ralph-loop、orchestrate、advisor が該当します。pstack は個人作者 (Lauren Tan / poteto) の plugin です。「go deep first」を掲げ、まず 1 agent を深く信頼できる状態にしてから並列化する、という考え方をとります。harness の方針を決めるうえでは、個別の plugin より設計原則の資料が参考になります。Anthropic と OpenAI の一次資料が共通して挙げる原則は次のとおりです。progress log、JSON の feature list、git commit で session をまたいで状態を引き継ぐこと。作業する agent と評価する agent を分けること。AGENTS.md は短い目次にして docs/ を system of record にすること。不変条件は linter や structural test で機械的に強制すること。model が良くなったら harness を削ること。形式は SKILL.md (Agent Skills)、AGENTS.md、MCP が AAIF (Linux Foundation) 配下の cross-vendor 標準になりました。そのため、特定の tool に依存しない形で整備できます。一方、公開 registry の skill は 13.4% に critical な問題が見つかっています。外部 skill を取り込むときは審査を前提にすべきです。dozou は data 基盤なので、dbt Labs 公式の dbt-agent-skills も候補になります。

## 主な発見

### 1. pstack (cursor/plugins、作者 Lauren Tan / poteto) は「書くコードを減らし、質を上げる」ことを目指す plugin です

pstack (cursor/plugins、作者 Lauren Tan / poteto) は「書くコードを減らし、質を上げる」ことを目指す plugin です。motto は「go fast するなら go deep first」で、まず 1 agent を深く信頼できる状態にしてから、poteto-mode などで複数 agent を並列に走らせる、という考え方をとります。ただし公式 repo に掲載されていても、Cursor 自身が作った plugin ではなく個人作者のものです。「core plugin」という区分も repo には存在しません。

- 確度: medium (verification vote 3-0)
- 根拠: README の plugin 表では Developer Tools に分類され、作者は Lauren Tan と書かれています。pstack README の署名は poteto です。dyl-stack が pstack を土台にしていると明記しています。一次資料ですが 1 つだけで、品質向上の効果を示すデータはありません。
- 出典: <https://github.com/cursor/plugins>

### 2. cursor/plugins には Cursor が作った自律実行向けの plugin が複数あります

cursor/plugins には Cursor が作った自律実行向けの plugin が複数あります。ralph-loop は Ralph Wiggum 手法による自己参照的な反復 loop です。orchestrate は planner、worker、verifier の役割と構造化された handoff を使い、大きな task を並列の cloud agent に分配します。advisor は重要な判断の前、行き詰まったとき、完了を宣言する前に、より強い model に相談します。harness の構成要素 (loop、並列化、二次意見) をそのまま示す例として参考になります。

- 確度: high (verification vote 3-0)
- 根拠: README の表の記述と claim がほぼ一字一句一致します (2026-11-26 に取得)。
- 出典: <https://github.com/cursor/plugins>

### 3. obra/superpowers は composable な skill 群で作られた開発方法論です

obra/superpowers は composable な skill 群で作られた開発方法論です。brainstorming → using-git-worktrees → writing-plans → subagent-driven-development または executing-plans → test-driven-development → requesting-code-review → finishing-a-development-branch の順に進める必須の workflow を定めています。README には、plan から外れずに数時間自律で動くことも珍しくないと書かれていますが、これは作者の主張で、裏付けのデータはありません。この環境にはすでに導入済みです (v7.0.2)。

- 確度: medium (verification vote 3-0)
- 根拠: README の 'The Basic Workflow' 節と、数時間の自律実行に関する原文を確認しました。workflow の内容は一次資料で確かめられますが、効果の主張は作者本人のものだけです。subagent-driven-development の詳しい挙動 (task ごとに review して block する) についての claim は 1-2 で否定されたので、ここには含めていません。
- 出典: <https://github.com/obra/superpowers>

### 4. feature-dev は Anthropic verified の公式 Claude Code plugin です (anthropics/claude-plugins-official)

feature-dev は Anthropic verified の公式 Claude Code plugin です (anthropics/claude-plugins-official)。/feature-dev で 7 phase の workflow を実行します (discovery、codebase exploration、clarifying questions、architecture design、implementation、quality review、summary)。使う subagent は 3 つです。code-explorer は実行経路をたどり、code-architect は trade-off 付きで複数案を出し、code-reviewer は confidence score 付きで bug、security、規約違反を指摘します。

- 確度: high (verification vote 3-0)
- 根拠: Anthropic 公式ページに verified badge、source link、7 phase、3 agent の説明があります。anthropics/claude-code repo の plugin 構成とも一致します。
- 出典: <https://claude.com/plugins/feature-dev>

### 5. Anthropic が推奨する長時間 agent 向けの harness は 2 段構成です

Anthropic が推奨する長時間 agent 向けの harness は 2 段構成です。最初の session では initializer agent が init.sh、claude-progress.txt (進捗 log)、全機能を failing で始める JSON の feature list、初回 git commit を用意します。以降の session では coding agent が 1 度に 1 機能だけを進め、説明的な commit と progress を残し、main に merge できる clean な状態で終えます。feature list を Markdown ではなく JSON にするのは、model が勝手に書き換えにくいからです。agent が変えてよいのは passes field だけで、test の削除や編集は禁止されています (prompt での指示であり、tool による強制ではありません)。

- 確度: high (verification vote 3-0)
- 根拠: Anthropic Engineering の記事 (2025-11-26) に、init.sh と claude-progress.txt、JSON 採用の理由、「It is unacceptable to remove or edit tests」、one feature at a time、clean state の定義が書かれています。
- 出典: <https://anthropic.com/engineering/effective-harnesses-for-long-running-agents>

### 6. 作る agent と評価する agent を分けるべきです

作る agent と評価する agent を分けるべきです。Anthropic は長時間の app 構築で 3 agent 構成をとりました。planner が短い prompt を spec に展開し、generator が sprint 単位で作り、evaluator が Playwright MCP で実際の app を user と同じように操作します。evaluator は UI、API、DB の状態を確かめ、各基準に hard threshold を設けます。自分の成果物を採点させると評価が甘くなるので、懐疑的な evaluator を別に用意して調整するほうがずっと扱いやすい、という結論です。ただし evaluator も LLM なので甘さは完全には消えません。後の簡略版では sprint をやめ、最後に 1 回だけ評価しています。

- 確度: high (verification vote 3-0)
- 根拠: Anthropic Labs の記事 (2026-03-24) で、引用文と Playwright MCP の使い方を確認しました。同じ考え方は cursor の orchestrate (verifier) と advisor にも見られます。
- 出典: <https://anthropic.com/engineering/harness-design-long-running-apps>

### 7. OpenAI の harness engineering の要点は 3 つです

OpenAI の harness engineering の要点は 3 つです。1 つ目に、AGENTS.md は約 100 行の目次 (map) にとどめ、構造化した docs/ を system of record にします。2 つ目に、layer の依存方向、structured logging、命名、file size などの不変条件を custom linter と structural test で機械的に強制します。lint の error message には agent 向けの修正指示を入れます。定期的に走る doc-gardening agent が古くなった docs の修正 PR を出します。3 つ目に、Codex は自分の変更を review し、追加の agent review を依頼して、全 reviewer が満足するまで loop します (Ralph Wiggum Loop)。人間による PR review は任意です。

- 確度: high (verification vote 3-0)
- 根拠: OpenAI の記事 (2026-02-11) で、「give Codex a map, not a 1,000-page instruction manual」と「Humans may review pull requests, but aren't required to」を確認しました。1 チームの実践例であり、一般的な best practice として示されたものではありません。dozou の AGENTS.md + docs/strategies/ 構成と直接対応します。
- 出典: <https://openai.com/index/harness-engineering/>

### 8. Anthropic (Lance Martin) は harness 設計の原則を 3 つ挙げています

Anthropic (Lance Martin) は harness 設計の原則を 3 つ挙げています。(1) bash や text editor のように Claude が使い慣れた汎用 tool に頼る。(2) model が良くなったら harness の logic を削る。(3) cost、UX、security の境界は意図して決める。実例として、Sonnet 4.5 が早めに作業を切り上げる問題に入れた context reset が、Opus 4.5 では不要な重荷になりました。model が変わるたびに前提を再検証して足場を減らすべき、という主張です。

- 確度: high (verification vote 3-0)
- 根拠: 2026-04-02 の記事で、「dead weight in the agent harness」という表現と 3 pattern の見出しを確認しました。vendor の経験談で、benchmark ではありません。
- 出典: <https://claude.com/resources/articles/harnessing-claudes-intelligence>

### 9. 可搬性の土台となる標準は AAIF (Agentic AI Foundation、Linux Foundation 配下) にまとまっています

可搬性の土台となる標準は AAIF (Agentic AI Foundation、Linux Foundation 配下) にまとまっています。founding projects は AGENTS.md (OpenAI)、MCP (Anthropic)、goose (Block) です。2026-10 には Anthropic が Agent Skills 標準 (SKILL.md、agentskills.io) も AAIF に寄贈しました。Agent Skills は ChatGPT、Cursor、GitHub Copilot、VS Code など 70 以上の platform で使われ、AGENTS.md は 60,000 以上の project で採用されています (どちらも vendor 自身の数字)。SKILL.md 形式は tool をまたいで使えますが、配置する directory は tool ごとに違います (.claude/skills、.cursor/skills、.github/skills、.agents/skills)。

- 確度: high (verification vote 3-0)
- 根拠: Anthropic (2026-10-22) と OpenAI (2025-12-09) の一次発表、および Linux Foundation の press release です。goose は標準ではなく agent 実装です。
- 出典: <https://www.anthropic.com/news/donating-agent-skills-to-the-agentic-ai-foundation>, <https://openai.com/index/agentic-ai-foundation/>

### 10. 外部の skill を取り込むと supply chain risk が大きくなります

外部の skill を取り込むと supply chain risk が大きくなります。Snyk が ClawHub と skills.sh の skill 3,984 件を調べたところ (2026-02-05 時点)、36.82% (1,467 件) に何らかの欠陥がありました。13.4% (534 件) は critical (prompt injection、悪性 code、不審な download) で、人手で確認した malicious payload は 76 件でした。

- 確度: medium (verification vote 3-0)
- 根拠: Snyk の一次調査です (方法の説明あり)。security vendor による調査で、対象は 2 つの registry だけ、時点は約 10 か月前です。13.4% は自動検出の値で、76 件は人手で確認した別の数字です。
- 出典: <https://snyk.io/jp/blog/toxicskills-malicious-ai-agent-skills-clawhub/>

### 11. data 基盤 (dozou) 向けには、dbt Labs が公式の dbt-labs/dbt-agent-skills を公開しています

data 基盤 (dozou) 向けには、dbt Labs が公式の dbt-labs/dbt-agent-skills を公開しています。Claude Code では /plugin marketplace add dbt-labs/dbt-agent-skills と /plugin install dbt@dbt-agent-marketplace で導入できます。他の agent では npx skills add で導入できます。

- 確度: medium (verification vote 3-0)
- 根拠: dbt Labs の公式 blog (2026-02-05) です。sandbox の制約で GitHub repo の現状は確認できていません。
- 出典: <https://docs.getdbt.com/blog/dbt-agent-skills>

## 注意点

- 個別 plugin の情報の多くは作者や vendor 自身の README・発表に頼っています。自律実行の性能や品質を第三者が比べた benchmark は見つかっていません。特に superpowers の「数時間自律で動く」と pstack の品質向上は、主張にとどまります。
- 「core plugin」は cursor/plugins の公式区分ではありません。pstack は個人作者の plugin です。
- 普及の数字 (70 以上の platform、60,000 以上の project) は vendor が自分で発表したもので、AGENTS.md の数字は 2025-12 時点のものです。
- Snyk のデータは 2026-02 時点のもので、対象は 2 つの registry だけです。
- 調査中は sandbox で GitHub (*.github.com) への接続が拒否されていました。そのため dbt-agent-skills などの repo の最新状態は直接確認していません。
- Anthropic の harness 記事は、model の世代ごとに前提が変わると自ら述べています (context reset が不要になった例)。ここで紹介した pattern も、時間が経てば古くなる前提で扱う必要があります。
- superpowers の subagent-driven-development の詳しい挙動についての claim は検証で否定されました。

## 未解決の問い

- pstack、superpowers、feature-dev の workflow は互いに重なっています。併用したとき (skill の自動起動の競合や context の消費) にどう振る舞うかは調べていません。
- dozou のように個人で運用する data 基盤 (dlt、dbt、DuckDB など) で、Anthropic の initializer + JSON feature list や evaluator 分離の pattern がどの程度そのまま使えるかは、まだ確認できていません。
- 外部の skill や plugin を取り込むときの審査手順 (version の pin、scan、許可する domain や権限の制限) を、harness の方針としてどこまで決めるべきかは未検討です。
- cross-tool で使えるようにするには、skill をどの directory に置くか (.agents/skills、.claude/skills など) を決める必要があります。どの配置にするのがよいかは調べていません。

## 否定された主張

- (1-2) subagent-driven-development dispatches a fresh subagent for each task and reviews after each one. Critical issues found in review between tasks block progress. — <https://github.com/obra/superpowers>

## 情報源

| URL | 品質 | 観点 |
|---|---|---|
| <https://github.com/cursor/plugins> | primary | pstack / Cursor plugins |
| <https://flaviocopes.com/pstack> | blog | pstack / Cursor plugins |
| <https://cursor.com/fr/lp-team/lauren> | unreliable | pstack / Cursor plugins |
| <https://github.com/obra/superpowers> | primary | Claude Code の人気 plugin / skill |
| <https://levelup.gitconnected.com/this-plugin-makes-claude-code-work-for-hours-without-going-off-the-rails-f176e474b284> | unreliable | Claude Code の人気 plugin / skill |
| <https://claude.com/plugins/feature-dev> | primary | Claude Code の人気 plugin / skill |
| <https://awesomeclaude-ai.nuxt.dev/ralph-wiggum> | blog | Claude Code の人気 plugin / skill |
| <https://claudemarketplaces.com/plugins/anthropics-claude-plugins-official> | secondary | Claude Code の人気 plugin / skill |
| <https://alirezarezvani.github.io/claude-skills/guides/best-claude-code-plugins/> | blog | Claude Code の人気 plugin / skill |
| <https://anthropic.com/engineering/effective-harnesses-for-long-running-agents> | primary | Harness engineering の実践 |
| <https://anthropic.com/engineering/harness-design-long-running-apps> | primary | Harness engineering の実践 |
| <https://openai.com/index/harness-engineering/> | primary | Harness engineering の実践 |
| <https://claude.com/resources/articles/harnessing-claudes-intelligence> | primary | Harness engineering の実践 |
| <https://addyosmani.com/blog/agent-harness-engineering/> | blog | Harness engineering の実践 |
| <https://github.com/walkinglabs/awesome-harness-engineering> | secondary | Harness engineering の実践 |
| <https://www.anthropic.com/news/donating-agent-skills-to-the-agentic-ai-foundation> | primary | Cross-tool の skill 標準 |
| <https://openai.com/index/agentic-ai-foundation/> | primary | Cross-tool の skill 標準 |
| <https://developers.redhat.com/articles/2026/08/18/securing-claude-code-plug-ins-best-practices-repository-security> | secondary | リスクと懐疑的な見方 |
| <https://snyk.io/jp/blog/toxicskills-malicious-ai-agent-skills-clawhub/> | primary | リスクと懐疑的な見方 |
| <https://www.sentinelone.com/blog/marketplace-skills-and-dependency-hijack-in-claude-code> | unreliable | リスクと懐疑的な見方 |
| <https://docs.getdbt.com/blog/dbt-agent-skills> | primary | データ基盤向けの agent 活用 |
| <https://dlthub.com/docs/hub/ai-harness/introduction> | primary | データ基盤向けの agent 活用 |
| <https://www.getdbt.com/blog/dbt-agents-remote-dbt-mcp-server-trusted-ai-for-analytics> | primary | データ基盤向けの agent 活用 |
