@echo OFF
set commitMsg=temp-vanilla-files

CALL update.bat -np
CALL commit.bat
CALL write.bat -np
CALL cleanup.bat -np

echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.

pause
