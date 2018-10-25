@ECHO off&setlocal
IF "%rootPath%"=="" (
	for %%i in ("%~dp0..") do set "rootPath=%%~fi"
	set updateLog="%rootPath%\build.log"
)

IF "%1"=="" (
	echo.
	echo Invalid argument, run update script.
	echo.
	goto end
)

set targetDir=%1
echo Copying %targetDir% files...
set src=%gamePath%\%targetDir%
set dest=%rootPath%\%targetDir%
IF not exist "%src%" goto notfound
robocopy /s "%src%" "%dest%" /IT >> %updateLog%
goto end

:notfound
echo [Error] Unable to find "%targetDir%" in game directory!
echo.

:end
