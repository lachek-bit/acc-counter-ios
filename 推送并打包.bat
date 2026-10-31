@echo off
chcp 65001 >nul
cd /d "%~dp0"
set HTTP_PROXY=http://127.0.0.1:7897
set HTTPS_PROXY=http://127.0.0.1:7897

echo ============================================
echo   账号计数器 iOS - 推送代码触发云端打包
echo ============================================
echo.
echo 推送分支：acc-counter（不会动 main 分支的小助手代码）
echo 代理：127.0.0.1:7897（需要 Clash 开着）
echo.
echo 稍等会弹出 GitHub 登录窗口，授权后自动推送...
echo.

git -c user.name="acc-counter" -c user.email="acc@local" add -A
git -c user.name="acc-counter" -c user.email="acc@local" commit -m "更新 iOS 工程" 2>nul
git push -u origin acc-counter

if %errorlevel%==0 (
  echo.
  echo ============================================
  echo   推送成功！
  echo.
  echo   接下来去这里看构建进度（约 5-10 分钟）：
  echo   https://github.com/lachek-bit/xiaozhushou-ios/actions
  echo.
  echo   构建完成后在 Artifacts 里下载 AccCounter-unsigned-ipa
  echo ============================================
) else (
  echo.
  echo 推送失败：检查 Clash 是否开着（端口 7897）、GitHub 是否登录
)
echo.
pause
