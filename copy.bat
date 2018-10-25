@echo OFF

set targetDir=%1
echo Copying %targetDir% files...
set src=%gamePath%\%targetDir%
set dest=%rootPath%\%targetDir%
IF not exist "%src%" goto notfound
robocopy /s "%src%" "%dest%" /IT >> vanilla-update.log
goto end

:notfound
echo [Error] Unable to find "%targetDir%" in game directory!
echo.

:end