# PII Redaction Guide / 個人情報除去ガイド

This guide describes a practical workflow for removing personal information from `loglm` logs before sharing them for research or review.
この文書では、研究利用や共有の前に `loglm` のログから個人情報を取り除くための実践的な手順を説明します。

日本語で読みたい場合は、この文書の下半分にある「日本語」節を参照してください。

## English

### Goal

Create `*.redacted.txt` files from `loglm` logs while preserving the original raw and decoded logs.

### Recommended Workflow

1. Prepare a `pii-candidates.txt` file.
   - Add as many likely personal identifiers as you can think of.
   - Use one group per person or entity.
   - Separate groups with a blank line.
   - Within each group, list full names, surnames, given names, usernames, email addresses, and other literal identifiers.

2. Decode the raw logs.

```bash
loglm-decode logs/*
```

3. Remove any old redacted outputs.

```bash
rm logs/*.redacted.txt
```

4. Generate redacted logs from the decoded logs.

```bash
loglm-decode --review-pii --replace-all pii-candidates.txt logs/*.decoded.txt
```

5. Ask an LLM to inspect the resulting `*.redacted.txt` files.
   - Ask it to identify any remaining strings that may reveal personal identity.
   - Review the suggestions yourself.

6. If needed, add the newly found strings to `pii-candidates.txt`.

7. Repeat steps 3-6 until you are satisfied.

8. Archive only the `*.redacted.txt` files for submission or sharing.

```bash
zip redacted-logs.zip logs/*.redacted.txt
```

### Notes

- `loglm-decode --review-pii` never edits raw log files.
- Raw `*.txt` and decoded `*.decoded.txt` files are preserved.
- `*.redacted.txt` files are the working copies for redaction.
- If a `*.redacted.txt` file is reviewed again, it is updated in place.
- Each group is replaced with a numbered token such as `***1*`, `***2*`, and so on.
- This keeps person-to-person relationships readable after redaction.

### Candidate List Format

- One literal string per line
- Empty lines separate groups
- Lines beginning with `#` are treated as comments

Example:

```text
# names
Kenji Saito
Kenji
Saito
ks91
ks91@waseda.jp

Natsume Soseki
Natsume
Soseki
```

## 日本語

### 目的

`loglm` のログから個人情報を取り除いた `*.redacted.txt` を作成し、元の raw ログと decoded ログは保持したまま研究利用や共有に備える。

### 推奨ワークフロー

1. `pii-candidates.txt` を用意する。
   - 思いつく限りの個人情報文字列を入れる。
   - 1人または1主体を1グループとして書く。
   - グループ同士は空行で区切る。
   - 各グループには、フルネーム、姓、名、ユーザー名、メールアドレスなどの文字列を含める。

2. まず raw ログを decoded にする。

```bash
loglm-decode logs/*
```

3. 古い `*.redacted.txt` を削除する。

```bash
rm logs/*.redacted.txt
```

4. `*.decoded.txt` から `*.redacted.txt` を作る。

```bash
loglm-decode --review-pii --replace-all pii-candidates.txt logs/*.decoded.txt
```

5. 生成された `*.redacted.txt` を LLM に見てもらう。
   - まだ個人情報に当たりうる文字列が残っていないか確認してもらう。
   - その提案を人間が確認する。

6. 必要なら、その追加候補を `pii-candidates.txt` に追記する。

7. 納得いくまで 3-6 を繰り返す。

8. 最後に `*.redacted.txt` だけを ZIP 化して提出・共有する。

```bash
zip redacted-logs.zip logs/*.redacted.txt
```

### 注意

- `loglm-decode --review-pii` は raw ログを編集しない。
- raw の `*.txt` と decoded の `*.decoded.txt` は保持される。
- 個人情報除去の作業対象は `*.redacted.txt` である。
- `*.redacted.txt` に対して再度 `--review-pii` を実行した場合、そのファイルを上書き更新する。
- 各グループは `***1*`, `***2*` のような番号付きトークンに置換される。
- これにより、個人を隠しつつ人物間の関係を読み取りやすくできる。

### 候補リストの書式

- 1 行に 1 文字列
- 空行はグループの区切り
- `#` で始まる行はコメントとして扱われる

例:

```text
# names
斉藤賢爾
斉藤
賢爾
ks91
ks91@waseda.jp

夏目漱石
Natsume Soseki
Natsume
Soseki
```
