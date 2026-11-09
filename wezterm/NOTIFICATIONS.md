# 通知

Claude Code固有の処理は `claude/hooks/`、Codex固有の処理は `codex/notify.sh` に置き、WezTerm側ではツールに依存しない
通知・未読・履歴を扱います。zsh・tmuxの設定変更は不要です。

- `Cmd+Shift+I`：このウィンドウの通知一覧。選択すると通知元のペインへ移動。
- `Cmd+Shift+N`：このウィンドウの最新の未読通知へ移動。
- 未読通知のあるタブにはベルを表示。通常の未閲覧出力の丸印とは別。
- 通知元のペインを見ている間はバナーを抑制。それ以外はデスクトップ通知。
- アプリが前面で対象ペインを表示すると既読になる（最大約1秒）。
- 履歴は最新100件。設定の再読込では保持し、WezTerm終了時に消える。
- 閉じたペインの履歴は一覧・移動の対象から除外。

Linux/Windowsでは `Cmd` の代わりに `Alt` を使用します。

## 他のツールから使う

Python 3が必要です。PATHの変更は行わないため、共通コマンドはパスで呼び出します。

```sh
~/.config/wezterm/bin/term-notify --title Build 'ビルドが完了しました'
~/.config/wezterm/bin/term-notify --clear

# 成功時だけ通知する例
make build && ~/.config/wezterm/bin/term-notify --title Build 'ビルド成功'
```

`WEZTERM_PANE` を継承するローカルのシェル・フックでは、`wezterm cli list` から
送信先TTYを特定して書き込みます。標準出力が捕捉されるフックでも動作し、
ペインが消えている場合は別のペインへ送らずエラーにします。
CLIで端末を新規起動することはありません。

継承した `WEZTERM_UNIX_SOCKET` のファイルが消えている場合は、その変数をCLI呼び出し時だけ
除外して現在のWezTermを検出し直します。シェルやマルチプレクサの環境は変更しません。
検出後も `WEZTERM_PANE` に対応するペインがなければ送信を止めます。

ローカルのtmux内でも、継承した `WEZTERM_PANE` が正しければ外側のWezTermへ直接送ります。
tmuxのpassthrough設定は不要です。ただし移動先はWezTermのペインであり、tmux内部のペインは選択しません。
古い環境のペインIDが現在の別ペインで再利用されている場合までは識別できません。
別の端末で起動したtmuxサーバーなどでは、必要に応じて `--pane-id ID` で対象を明示してください。

SSH先からの自動ルーティングは対象外です。`--tty` / `TERM_NOTIFY_TTY` は端末を明示する
統合向けの入口ですが、リモートフックへのTTY引き渡しやtmuxのpassthrough設定は自動では行いません。

通知にはWezTerm自身のネイティブ通知機能を使います。Script Editor・AppleScript・
`osascript`・外部の通知アプリには依存しません。
WezTerm以外では標準のOSC 777通知を端末へ送ります（受信端末の対応が必要です）。

## Claude Codeとの接続

既存の `~/.claude/hooks/notify.sh` が共通コマンドを呼び出します。
`Stop` は既存の `stop-guard.sh` の判定後に通知し、続行を指示した場合は通知しません。
`Notification` では承認待ちなどを通知し、`UserPromptSubmit` で未読を解除します。
内部判定用のheadless Claudeとサブエージェントは通知対象外です。

本文はリポジトリ名・ブランチ名に続けて、最終応答のプレビュー（最大240文字）を表示します。
承認待ちなどは実際の通知メッセージを表示し、本文が取得できない場合だけ定型文を使います。

`Stop` の通知は「応答終了」です。成功の保証やバックグラウンド処理の完了とは区別します。
バックグラウンド処理が報告されている場合はその旨を通知します。
他のプラグインのStopフックが続行を指示する場合まで、このフックで判定することはできません。

WezTermは設定を自動再読込します。Claude Codeは新しいセッションでフック設定を読み込んでください。
macOSのWezTerm通知許可・集中モードによってはバナーが出なくても一覧には記録されます。
macOS上のWezTerm `20240203` ではTemporaryのバナーが出ない[既知の報告](https://github.com/wezterm/wezterm/issues/5476)があります。
この環境では通知スタイルをPersistentに変更し、ネイティブ通知の表示を確認済みです。

## Codex CLIとの接続

`codex/config.toml` の `notify` は既存のComputer Useラッパーを維持し、
`--previous-notify` で `codex/notify.sh` にイベントJSONを渡します。
`agent-turn-complete` を共通通知コマンドへ変換し、Claude Codeと同じ未読表示・履歴・移動を使います。
本文には作業ディレクトリ名・ブランチ名と最終応答のプレビュー（最大240文字）を表示します。
Script Editor・AppleScriptは使いません。反映には新しいCodex CLIセッションを開いてください。

この接続は応答終了イベントが対象です。承認待ちのイベントや、プロンプト送信時の自動既読解除は含みません。
ペインの表示による既読解除は共通機能として動作します。

## 通知プロトコル

OSC 1337の `SetUserVar=term_notify` にUTF-8 JSONをBase64化して渡します。
`term-notify --backend wezterm --stdout` で実際のシーケンスを生成できます。

```json
{"version":1,"id":"unique-event-id","op":"notify","title":"Build","body":"Finished"}
```

同じ `id` は保持中の履歴内で重複排除します。既読への変更は
`{"version":1,"op":"clear"}` です。制御文字は表示前に除去・置換し、不正な入力は無視します。

## 検証

リポジトリのルートから実行します。実通知やLLM呼び出しは発生しません。
Pythonのテストには、WezTerm本体のLua環境・共有状態で受信から履歴・未読解除・移動まで
検証するテストも含まれます（WezTerm未インストール時はその1件のみスキップします）。

```sh
python3 -B -m unittest discover -s wezterm/tests -p 'test_*.py'
lua wezterm/tests/notifications.lua
wezterm show-keys --lua
```

参照：[WezTerm user-var-changed](https://wezterm.org/config/lua/window-events/user-var-changed.html)、
[toast_notification](https://wezterm.org/config/lua/window/toast_notification.html)、
[Claude Code hooks](https://code.claude.com/docs/en/hooks)。
