@echo OFF

IF "%1"=="--no-reset" ( goto :clean )

:input
git log -1 --pretty=%%B > clean.tmp
( set /p commit= ) < clean.tmp
IF not "%commit%"=="%commitMsg%" (
	echo This script will drop your last commit and remove all untracked changes.
	goto check
)
goto start

:check
set /p input="Are you sure you want to continue? (y/n): "
IF "%input%"=="y" (
	echo.
	copy NUL build.log
	goto start
)
IF "%input%"=="n" ( goto pause )
goto check

:start
echo Resetting repository head...
git reset HEAD~ >> build.log
:clean
echo Cleaning repository...
git stash save --keep-index --include-untracked >> build.log
git stash drop >> build.log

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
