@echo OFF
CALL vanilla-update.bat -c
git config --global core.safecrlf false > generate-diff.log
echo Adding file contents to index...
git add * >> generate-diff.log
echo Recording changes to repository...
git commit -m "Add temp vanilla files" >> generate-diff.log
echo Writing diff to file...
git diff --diff-filter=M master vanilla > vanilla.diff
echo Cleaning repository...
git reset HEAD~ >> generate-diff.log
git stash save --keep-index --include-untracked >> generate-diff.log
git stash drop >> generate-diff.log
echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.
pause
