@ECHO off
echo.

:init
IF exist "error.log" del error.log

set this=%~nx0
set config="vanilla.ini"
set updateLog="update.log"
set buildLog="build.log"
set installLog="install.log"

git diff HEAD > build.tmp
for /f %%i in ("build.tmp") do set size=%%~zi
IF %size% gtr 0 (
	echo Stashing changes in working directory...
	git add %this% >> %buildLog%
	git add %config% >> %buildLog%
	git stash save --keep-index >> %buildLog%
)

:run
call :install
call :readIni
call :copyFiles
IF "%1"=="--update" (
	goto EOF
)
call :trimFiles
call :createCommit
call :writeDiff
IF "%1"=="--dirty" (
	echo Skipping cleanup.
) else (
	call :cleanRepo
)
echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.
goto EOF

:install
IF not EXIST "JREPL.BAT" (
	echo Regex text processor not found.
	echo Downloading package...
	powershell -Command "(New-Object Net.WebClient).DownloadFile('https://www.dostips.com/forum/download/file.php?id=390&sid=3bb47c363d95b5427d516ce1605df600', 'JREPL.zip')" > %installLog%
	echo Extracting package...
	7z e -aoa JREPL.zip >> %installLog%
	del JREPL.zip >> %installLog%
	IF not EXIST "JREPL.BAT" ( call :CTError 5 )
	echo Finished installing JREPL.
	del %installLog%
	echo.
)
exit /b

:readIni
IF not EXIST %config% ( call :CTError 1 )
(
set /p entry1=
set /p gamePath=
set /p entry2=
set /p txtFiles=
) < %config%

IF not "%entry1%"=="gamePath =" ( call :CTError 2 gamePath )
set gamePath=%gamePath:"=%
IF not EXIST "%gamePath%\eu4.exe" ( call :CTError 3 gamePath )
IF not "%entry2%"=="txtFiles =" ( call :CTError 2 txtFiles )
exit /b

:copyFiles
echo Creating list of files on master branch...
git ls-tree -r master --name-only > master.diff
call jrepl "(\/)" "\" /f "master.diff" /o -

echo Preparing to copy files...

set fileCategory=""
IF exist files.diff del files.diff >> %buildLog%
copy NUL files.diff >> %buildLog%

echo.
echo. > %updateLog%
for /F "usebackq tokens=*" %%a in (master.diff) do (
	echo %%a > build.tmp
	call jrepl "\\(.*(?:\\))?" " " /f "build.tmp" /o -
	for /F "usebackq tokens=*" %%b in (build.tmp) do (
		call :CopyFile %%b %%a
	)
)
echo.
echo Completed copying vanilla files!
echo Operation log saved in 'update.log'
echo.
exit /b

:trimFiles
echo Trimming trailing space...
for /F "usebackq tokens=*" %%a in (files.diff) do (
	echo trim %%a >> %buildLog%
	call jrepl "\s+$" "" /x /f "%cd%\%%a" /o -
)
exit /b

:createCommit
git config --global core.safecrlf false >> %buildLog%

echo Adding file contents to index...
git add * >> %buildLog%
git reset -- %this% >> %buildLog%
git reset -- %config% >> %buildLog%

git rev-parse HEAD > build.tmp
( set /p oldHEAD= ) < build.tmp

echo Recording changes to repository...
git commit -m "temp-vanilla-files" >> %buildLog%

git rev-parse HEAD > build.tmp
( set /p newHEAD= ) < build.tmp
IF "%oldHEAD%"=="%newHEAD%" (
	call :CTError 6
)
exit /b

:writeDiff
echo Writing diff to file...
git diff --diff-filter=M master vanilla > vanilla.diff
exit /b

:cleanRepo
git rev-parse HEAD > build.tmp
( set /p curHEAD= ) < build.tmp
IF "%curHEAD%"=="%newHEAD%" (
	echo Cleaning repository...
	git reset --keep HEAD~ >> %buildLog%
) else (
	call :Error 4
)
del build.tmp
exit /b

:CopyFile <path>
set fileDirName=%1
set filename=%2
set filePath=%3

:: Get file path without filename
echo %filePath% > build.tmp
call jrepl "\\(?:[^\\](?!\\))+$" "" /f "build.tmp" /o -
( set /p filePath= ) < build.tmp
del build.tmp

IF not "%fileCategory%"=="%1" (
	IF not "%fileDirName%"=="%filename%" (
		set fileCategory=%1
		echo Copying "%1" files...
	)
)
set src=%gamePath%\%filePath%
set dest=%cd%\%filePath%
IF exist "%src%\%filename%" (
	robocopy "%src%" "%dest%" %filename% /IT >> %updateLog%
	:: Fill list of copied file paths
	echo %3 >> files.diff
)
exit /b

:Error <code> [<info>]

IF "%1"=="4" (
	echo Unexpected HEAD, something went wrong...
	echo Skipping cleanup.
)
exit /b

:CTError <code> [<info>]

IF "%1"=="1" (
	echo Missing config file, update your local repository.
)
IF "%1"=="2" (
	echo Missing '%2' entry in config file!
)
IF "%1"=="3" (
	echo Invalid '%2' entry in config file!
)
IF "%1"=="5" (
	echo Unable to install JREPL, read 'install.log' for more info.
)
IF "%1"=="6" (
	echo Failed to commit changes, read 'build.log' for more info.
)
echo.
echo Critical error occured, aborting operation!

:EOF
pause