@echo OFF

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
robocopy /s "%src%" "%dest%" /IT >> update.log
goto end

:notfound
echo [Error] Unable to find "%targetDir%" in game directory!
echo.

:end