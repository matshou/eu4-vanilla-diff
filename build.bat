@echo OFF
set commitMsg=temp-vanilla-files

git config --global core.safecrlf false > build.log
CALL update.bat -np
CALL commit.bat
echo Writing diff to file...
git diff --diff-filter=M master vanilla > vanilla.diff
CALL cleanup.bat -np

echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.

pause
