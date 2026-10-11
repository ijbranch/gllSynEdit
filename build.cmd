@echo off
rem ---------------------------------------------------------------------------
rem  Build and test everything this repository ships, in the order that works.
rem
rem  Usage:  build.cmd            packages + demos + tests
rem          build.cmd packages   the two packages only, four modes each
rem          build.cmd tests      the test suite only, both platforms
rem
rem  Exit code is 0 only if every build succeeded and every test passed.
rem ---------------------------------------------------------------------------
setlocal enabledelayedexpansion

set "BDS_DIR=C:\Program Files (x86)\Embarcadero\Studio\37.0"
if not exist "%BDS_DIR%\bin\rsvars.bat" (
  echo ERROR: RAD Studio 37.0 not found at "%BDS_DIR%".
  echo        Edit BDS_DIR at the top of this script.
  exit /b 2
)
call "%BDS_DIR%\bin\rsvars.bat" >nul

rem DUnitX source. Adjust if your checkout lives elsewhere; the RAD Studio DCUs
rem also work, but building from source keeps the test project self-contained.
if "%DUNITX%"=="" set "DUNITX=D:\gllDUnitX\Source"

set "ROOT=%~dp0"
set "FAILED=0"
set "WHAT=%~1"
if "%WHAT%"=="" set "WHAT=all"

rem ---------------------------------------------------------------------------
rem  Packages. Runtime BEFORE design-time: SynEditDD requires SynEditDR's .dcp,
rem  and building it first fails with E2225 on a stale or absent one.
rem ---------------------------------------------------------------------------
if "%WHAT%"=="all" goto :packages
if "%WHAT%"=="packages" goto :packages
goto :after_packages

:packages
echo.
echo === Packages: Win32 + Win64 x Debug + Release ===
for %%P in (SynEditDR SynEditDD) do (
  for %%C in (Debug Release) do (
    for %%L in (Win32 Win64) do (
      msbuild "%ROOT%Packages\11AndAbove\Delphi\%%P.dproj" /t:Build ^
        /p:Config=%%C /p:Platform=%%L /v:quiet /nologo >nul
      if errorlevel 1 (
        echo   FAIL  %%P %%C %%L
        set /a FAILED+=1
      ) else (
        echo   ok    %%P %%C %%L
      )
    )
  )
)
rem The package .res files carry the auto-incremented build number (2026-10-12), so a build
rem changing them is expected and is committed - they are no longer reverted here.

:after_packages
if "%WHAT%"=="packages" goto :summary

rem ---------------------------------------------------------------------------
rem  Demos. The only consumers of the public API in this repository.
rem ---------------------------------------------------------------------------
if "%WHAT%"=="all" (
  echo.
  echo === Demos: Win32 + Win64, Release ===
  for /r "%ROOT%Demos" %%D in (*.dproj) do (
    for %%L in (Win32 Win64) do (
      msbuild "%%D" /t:Build /p:Config=Release /p:Platform=%%L /v:quiet /nologo >nul
      if errorlevel 1 (
        echo   FAIL  %%~nD %%L
        set /a FAILED+=1
      )
    )
  )
  echo   done
)

rem ---------------------------------------------------------------------------
rem  Tests. A package build is a compile check; this is the behavioural gate.
rem ---------------------------------------------------------------------------
if "%WHAT%"=="all" goto :tests
if "%WHAT%"=="tests" goto :tests
goto :summary

:tests
echo.
echo === Tests: Win32 + Win64 ===
for %%L in (Win64 Win32) do (
  msbuild "%ROOT%Tests\SynEditTests.dproj" /t:Build /p:Config=Debug /p:Platform=%%L ^
    /p:DCC_UnitSearchPath="..\Source;..\Source\Highlighters;%DUNITX%" ^
    /v:quiet /nologo >nul
  if errorlevel 1 (
    echo   FAIL  build %%L
    set /a FAILED+=1
  ) else (
    "%ROOT%Tests\bin\%%L\Debug\SynEditTests.exe" --exitbehavior:Continue
    if errorlevel 1 (
      echo   FAIL  tests %%L
      set /a FAILED+=1
    )
  )
)

:summary
echo.
if "%FAILED%"=="0" (
  echo ALL GREEN
  exit /b 0
) else (
  echo %FAILED% FAILURE^(S^)
  exit /b 1
)
