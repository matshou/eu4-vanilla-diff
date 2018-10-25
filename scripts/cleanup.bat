@ECHO off&setlocal
IF "%rootPath%"=="" (
	for %%i in ("%~dp0..") do set "rootPath=%%~fi"
)
set buildLog="%rootPath%\build.log"

IF "%1"=="--no-reset" ( goto :clean )

:input
git log -1 --pretty=%%B > clean.tmp
( set /p commit= ) < clean.tmp
IF not "%commit%"=="%commitMsg%" (
	echo.
	echo This script will drop your last commit and remove all untracked changes.
	goto check
)
goto start

:check
set /p input="Are you sure you want to continue? (y/n): "
IF "%input%"=="y" (
	echo.
	echo. > %buildLog%
	goto start
)
IF "%input%"=="n" ( goto pause )
goto check

:start
echo Resetting repository head...
git reset HEAD~ >> %buildLog%
:clean
echo Cleaning repository...
git stash save --keep-index --include-untracked >> %buildLog%
git stash drop >> %buildLog%

IF not "%1"=="-np" (
	echo Finished cleaning!
	goto pause
)
goto end

:pause
echo.
pause

:end
IF exist "clean.tmp" (
del clean.tmp
)
