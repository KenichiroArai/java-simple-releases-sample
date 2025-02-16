@echo off
rem -*- mode: bat; coding: shift-jis -*-
chcp 932 > nul
setlocal enabledelayedexpansion

rem Git�̕����R�[�h�ݒ�
git config --local core.quotepath off
git config --local i18n.logoutputencoding shift-jis
git config --local i18n.commitencoding shift-jis

rem �����[�X�������X�N���v�g
rem ===========================================

if "%~1"=="" (
    echo �g�p���@�Frelease.bat [��ƃu�����`] [�����[�X�u�����`] [�o�[�W����]
    echo ��Frelease.bat features/release main 1.0.0
    exit /b 1
)

set WORK_BRANCH=%~1
set RELEASE_BRANCH=%~2
set VERSION=%~3

if not "%VERSION:~0,1%"=="v" (
    set VERSION=v%VERSION%
)

echo �����[�X�v���Z�X���J�n���܂�...
echo ��ƃu�����`: %WORK_BRANCH%
echo �����[�X�u�����`: %RELEASE_BRANCH%
echo �o�[�W����: %VERSION%

git fetch
if errorlevel 1 goto error

git checkout %WORK_BRANCH%
if errorlevel 1 goto error

git add .
git commit -m "�����[�X�����F���R�~�b�g�̕ύX��ǉ�" || echo ���R�~�b�g�̕ύX�Ȃ�

call mvn versions:set -DnewVersion=%VERSION:~1%
if errorlevel 1 goto error

git add pom.xml
git commit -m "�o�[�W������ %VERSION:~1% �ɍX�V" || echo �o�[�W�����ύX�Ȃ�

del pom.xml.versionsBackup

git pull origin %WORK_BRANCH% --rebase
if errorlevel 1 goto error

git diff %WORK_BRANCH% %RELEASE_BRANCH% --quiet
if %errorlevel% equ 0 (
    echo ��ƃu�����`�ƃ����[�X�u�����`�ɍ���������܂���B
    echo �v�����N�G�X�g���X�L�b�v���ă^�O�쐬�ɐi�݂܂��B
    goto create_tag
)

echo �ύX���v�b�V����...
git push origin %WORK_BRANCH%
if errorlevel 1 goto error

where gh >nul 2>nul
if %errorlevel% equ 0 (
    git diff %WORK_BRANCH% %RELEASE_BRANCH% --quiet
    if errorlevel 1 (
        echo �v�����N�G�X�g���쐬��...
        gh pr create --base %RELEASE_BRANCH% --head %WORK_BRANCH% --title "�����[�X%VERSION%" --body "�����[�X%VERSION%�̃v�����N�G�X�g�ł��B"
        if errorlevel 1 goto error
    ) else (
        echo �ύX���Ȃ����߁A�v�����N�G�X�g���X�L�b�v���܂��B
    )
) else (
    echo GitHub CLI ���C���X�g�[������Ă��܂���B
    echo �蓮�Ńv�����N�G�X�g���쐬���Ă��������B
    pause
)

echo �v�����N�G�X�g���}�[�W�����܂őҋ@���܂�...
echo �}�[�W������������ Enter �L�[�������Ă�������...
pause

:create_tag
git checkout %RELEASE_BRANCH%
if errorlevel 1 goto error

git pull origin %RELEASE_BRANCH%
if errorlevel 1 goto error

git tag -d %VERSION% 2>nul
git push origin :refs/tags/%VERSION% 2>nul
git tag %VERSION%
git push origin %VERSION%
if errorlevel 1 goto error

git pull origin %RELEASE_BRANCH%
if errorlevel 1 goto error

echo �����[�X�v���Z�X���������܂����B
echo GitHub Actions �Ń����[�X���쐬�����܂ł��҂����������B
exit /b 0

:error
echo �G���[���������܂����B
exit /b 1
