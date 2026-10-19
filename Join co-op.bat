@echo off
rem The Pink Valley - tag-along co-op (co-op add-on by gore).
rem Everything happens in launcher\tpv-coop.ps1. It checks for updates first, so keep this
rem file and the launcher folder together. The last line ends with "exit" on purpose: an
rem update can rewrite this file while it runs.
rem If PowerShell stops without explaining (blocked or killed), the window stays open.
title The Pink Valley co-op - JOIN
if not exist "%~dp0launcher\tpv-coop.ps1" (echo The launcher folder is missing. Unzip the whole "TPV co-op" folder again. & pause & exit /b 1)
rem Let Windows PowerShell use its own module folders even when started from PowerShell 7.
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\tpv-coop.ps1" join || (echo. & echo The launcher stopped without saying why. Send a screenshot of this window to whoever gave you the co-op files. & pause) & exit /b
