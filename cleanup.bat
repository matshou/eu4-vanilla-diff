@echo OFF

git log -1 --pretty=%%B > clean.tmp
( set /p commit= ) < clean.tmp
IF not "%commit%"=="%commitMsg%" (
	echo Invalid index, run update script before cleaning.
	del clean.tmp
	goto pause
)
echo Cleaning repository...
git reset HEAD~ >> generate-diff.log
git stash save --keep-index --include-untracked >> generate-diff.log
git stash drop >> generate-diff.log

:clean
del clean.tmp
IF not "%1"=="-c" (
	echo Finished cleaning!
	goto pause
)
goto end

:pause
echo.
pause

:end
