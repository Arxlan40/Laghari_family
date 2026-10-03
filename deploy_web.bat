@echo off
title Deploy Laghari Family Web to Firebase Hosting
echo ========================================================
echo   Deploying Laghari Family Web Application to Firebase
echo ========================================================
echo.

set FIREBASE_CMD="C:\Users\arsla\AppData\Local\Microsoft\WinGet\Links\firebase.exe"

echo [1/2] Checking Firebase Authentication...
%FIREBASE_CMD% projects:list >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Please log in with your Google account that owns 'laghari-family':
    %FIREBASE_CMD% login
)

echo.
echo [2/2] Deploying production bundle in build/web to Firebase Hosting...
%FIREBASE_CMD% deploy --only hosting

echo.
echo ========================================================
echo   Deployment Finished!
echo ========================================================
pause
