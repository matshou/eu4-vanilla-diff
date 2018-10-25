@echo OFF
echo.
set rootPath=%cd%

:readini

IF not EXIST "vanilla.ini" (
echo [Error] Missing configuration file, update your local repository.
goto end
)
(
set /p entry1=
set /p gamePath=
set /p entry2=
set /p fileList=
) < vanilla.ini

IF not "%entry1%"=="gamePath =" (
echo [Error] Missing 'gamePath' entry in config file!
goto end
)
set gamePath=%gamePath:"=%
IF not EXIST "%gamePath%\eu4.exe" (
echo [Error] Invalid 'gamePath' entry in config file!
goto end
)
IF not "%entry2%"=="fileList =" (
echo [Error] Missing 'fileList' entry in configuration file!
goto end
)

:copyfiles
echo. > output_log.txt
for %%a in (%fileList%) do ( CALL vanilla-copy.bat %%a )

:complete
echo.
echo Completed copying vanilla files!
echo Operation log saved in 'output_log.txt'
goto end

:end
echo.
IF not "%1"=="-c" ( pause )
