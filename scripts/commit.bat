@ECHO off

IF NOT DEFINED commitMsg (
	echo.
	echo Commit message not defined, run build script.
	echo.
	goto end
)

git config --global core.safecrlf false > build.log
echo Adding file contents to index...
git add * >> build.log
echo Recording changes to repository...
git commit -m "%commitMsg%" >> build.log

:end
