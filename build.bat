@echo OFF
set commitMsg=temp-vanilla-files

CALL scripts/update.bat -np
CALL scripts/commit.bat
CALL scripts/write.bat -np


echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.

pause
