@echo off
echo ========================================
echo   小象日记 - 部署到 GitHub Pages
echo ========================================
echo.

REM 1. 构建 Web 版本
echo [1/4] 构建 Web Release...
call flutter build web --release --base-href /elephant-diary/
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 构建失败
    pause
    exit /b 1
)

REM 2. 进入构建目录
cd /d build\web

REM 3. 如果还没 init，先 init
if not exist .git (
    echo [2/4] 初始化 Git...
    git init
    git checkout -b main
)
if exist ..\..\.git (
    echo [2/4] 跳过 - 已有 Git 仓库
) else (
    echo [2/4] Git 已就绪
)

REM 4. 提交 + 推送
echo [3/4] 提交文件...
git add -A
set /p COMMIT_MSG="请输入更新描述（直接回车为自动）: "
if "%COMMIT_MSG%"=="" set COMMIT_MSG=Deploy %date% %time%
git commit -m "%COMMIT_MSG%"

echo [4/4] 推送到 GitHub...
git push origin main 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️  推送失败。请确认：
    echo    1. 已在 github.com 创建仓库
    echo    2. 已关联远程仓库：git remote add origin https://github.com/你的用户名/仓库名.git
    echo    3. 仓库 Settings ^> Pages ^> Source 选 main 分支 ^> Save
    echo.
    echo 如果需要手动执行：
    echo    git remote add origin https://github.com/你的用户名/仓库名.git
    echo    git push -u origin main
    echo.
) else (
    echo.
    echo ✅ 部署完成！几分钟后在访问：
    echo    https://你的用户名.github.io/仓库名/
)

cd /d %~dp0
pause
