@ECHO off
set buildLog="%rootPath%\build.log"

IF NOT DEFINED commitMsg (
	echo.
	echo Commit message not defined, run build script.
	echo.
	goto end
)

git config --global core.safecrlf false > %buildLog%
echo Adding file contents to index...
git add * >> %buildLog%
echo Recording changes to repository...
git commit -m "%commitMsg%" >> %buildLog%

:end
