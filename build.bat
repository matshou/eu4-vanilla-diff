@echo OFF
set commitMsg=temp-vanilla-files

CALL update.bat -c
git config --global core.safecrlf false > build.log
CALL commit.bat
echo Writing diff to file...
git diff --diff-filter=M master vanilla > vanilla.diff
CALL cleanup.bat -c

echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.

pause
