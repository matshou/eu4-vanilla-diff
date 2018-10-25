@ECHO off

IF NOT DEFINED commitMsg (
	echo.
	echo Commit message not defined, run build script.
	goto pause
)

git config --global core.safecrlf false > build.log
echo Adding file contents to index...
git add * >> build.log
echo Recording changes to repository...
git commit -m "%commitMsg%" >> build.log
goto end

:pause
echo.
pause

:end
