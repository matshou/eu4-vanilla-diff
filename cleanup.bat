@echo OFF

git log -1 --pretty=%%B > clean.tmp
( set /p commit= ) < clean.tmp
IF not "%commit%"=="%commitMsg%" (
	echo This script will drop your last commit and remove all untracked changes.
	goto check
)
goto clean

:check
set /p input="Are you sure you want to continue? (y/n): "
IF "%input%"=="y" (
	echo.
	copy NUL build.log
	goto clean
)
IF "%input%"=="n" ( goto pause )
goto check

:clean
echo Resetting repository head...
git reset HEAD~ >> build.log
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
goto end

:end
del clean.tmp
