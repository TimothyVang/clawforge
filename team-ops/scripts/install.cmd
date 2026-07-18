@echo off
REM team-ops install wrapper for Windows cmd
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
