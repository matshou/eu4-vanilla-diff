@ECHO off&setlocal
IF "%rootPath%"=="" (
	for %%i in ("%~dp0..") do set "rootPath=%%~fi"
)
echo Writing diff to file...
git diff --diff-filter=M master vanilla > "%rootPath%\vanilla.diff"

IF not "%1"=="-np" (
	echo Finished writing diff file!
	echo See 'vanilla.diff'
	goto pause
)
goto end

:pause
echo.
pause

:end
