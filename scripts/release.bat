@ECHO OFF

REM SJISでコンソール出力を設定
CHCP 932 > NUL

SETLOCAL enabledelayedexpansion

REM PowerShellのエンコーディング設定
POWERSHELL -command "[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding('shift_jis')"
POWERSHELL -command "$OutputEncoding = [System.Text.Encoding]::GetEncoding('shift_jis')"

REM ===========================================
REM リリース自動化スクリプト
REM ===========================================
REM
REM このバッチファイルは、GitHubでのリリース作成プロセスを自動化します。
REM
REM 前提条件：
REM - GitHub アカウントを持っていること
REM - リポジトリへのプッシュ権限があること
REM - ローカル環境に以下がインストールされていること：
REM   - Java 21
REM   - Maven
REM   - Git
REM   - GitHub CLI（オプション：プルリクエストの自動作成に必要）
REM
REM 使用方法：
REM   release.bat [作業ブランチ] [リリースブランチ] [バージョン]
REM
REM 例：
REM   release.bat features/release main 1.0.0
REM
REM 注意事項：
REM - このファイルはSJISで保存してください
REM - 改行コードはCRLF（Windows形式）を使用してください
REM - バージョン番号の先頭の「v」は省略可能です（自動的に付加されます）
REM - プルリクエストのマージは手動で行う必要があります
REM - GitHub CLIがインストールされていない場合は、プルリクエストの作成は手動で行う必要があります
REM
REM ===========================================

REM パラメータのチェック
IF "%~1"=="" (
    ECHO 使用方法：release.bat [作業ブランチ] [リリースブランチ] [バージョン]
    ECHO 例：release.bat features/release main 1.0.0
    EXIT /b 1
)

SET WORK_BRANCH=%~1
SET RELEASE_BRANCH=%~2
SET VERSION=%~3

REM バージョン文字列の検証
IF NOT "%VERSION:~0,1%"=="v" (
    SET VERSION=v%VERSION%
)

ECHO リリースプロセスを開始します...
ECHO 作業ブランチ: %WORK_BRANCH%
ECHO リリースブランチ: %RELEASE_BRANCH%
ECHO バージョン: %VERSION%

REM リモートの最新情報を取得
git fetch
IF errorlevel 1 GOTO error

REM 作業ブランチに切り替え
git checkout %WORK_BRANCH%
IF errorlevel 1 GOTO error

REM 未コミットの変更をすべてコミット
git add .
git commit -m "リリース準備：未コミットの変更を追加" || ECHO 未コミットの変更なし

REM Mavenのバージョンを設定
call mvn versions:set -DnewVersion=%VERSION:~1%
IF errorlevel 1 GOTO error

REM バージョン変更をコミット
git add pom.xml
git commit -m "バージョンを %VERSION:~1% に更新" || ECHO バージョン変更なし

REM バックアップファイルを削除
DEL pom.xml.versionsBackup

REM リモートの変更を取り込む
git pull origin %WORK_BRANCH% --rebase
IF errorlevel 1 GOTO error

REM ブランチ間の差分をチェック
git diff %WORK_BRANCH% %RELEASE_BRANCH% --quiet
IF %errorlevel% equ 0 (
    ECHO 作業ブランチとリリースブランチに差分がありません。
    ECHO プルリクエストをスキップしてタグ作成に進みます。
    GOTO create_tag
)

ECHO 変更をプッシュ中...
git push origin %WORK_BRANCH%
IF errorlevel 1 GOTO error

REM プルリクエストの作成（ghコマンドがある場合）
WHERE gh >nul 2>nul
IF %errorlevel% EQU 0 (
    REM 変更があるか確認
    git diff %WORK_BRANCH% %RELEASE_BRANCH% --quiet
    IF errorlevel 1 (
        ECHO プルリクエストを作成中...
        gh pr create --base %RELEASE_BRANCH% --head %WORK_BRANCH% --title "リリース%VERSION%" --body "リリース%VERSION%のプルリクエストです。"
        IF errorlevel 1 GOTO error
    ) ELSE (
        ECHO 変更がないため、プルリクエストをスキップします。
    )
) ELSE (
    ECHO GitHub CLI がインストールされていません。
    ECHO 手動でプルリクエストを作成してください。
    PAUSE
)

REM プルリクエストのマージを待機
ECHO プルリクエストがマージされるまで待機します...
ECHO マージが完了したら Enter キーを押してください...
PAUSE

:create_tag
REM リリースブランチに切り替え
git checkout %RELEASE_BRANCH%
IF errorlevel 1 GOTO error

REM 最新の変更を取得
git pull origin %RELEASE_BRANCH%
IF errorlevel 1 GOTO error

REM タグの作成とプッシュ
REM 既存のタグを削除（存在しない場合はエラーを無視）
git tag -d %VERSION% 2>nul
REM リモートの既存タグを削除（存在しない場合はエラーを無視）
git push origin :refs/tags/%VERSION% 2>nul
REM 新しいタグを作成してプッシュ
git tag %VERSION%
git push origin %VERSION%
IF errorlevel 1 GOTO error

REM リリースブランチを最新化
git pull origin %RELEASE_BRANCH%
IF errorlevel 1 GOTO error

ECHO リリースプロセスが完了しました。
ECHO GitHub Actions でリリースが作成されるまでお待ちください。
EXIT /b 0

:error
ECHO エラーが発生しました。
EXIT /b 1
