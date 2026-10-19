@echo off
rem The Pink Valley - tag-along co-op (co-op add-on by gore).
rem Everything happens in launcher\tpv-coop.ps1. It checks for updates first, so keep this
rem file and the launcher folder together. The last line ends with "exit" on purpose: an
rem update can rewrite this file while it runs.
title The Pink Valley co-op - JOIN
if not exist "%~dp0launcher\tpv-coop.ps1" (echo The launcher folder is missing. Unzip the whole "TPV co-op" folder again. & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher\tpv-coop.ps1" join & exit /b
