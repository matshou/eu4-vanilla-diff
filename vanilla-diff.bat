@ECHO off
setlocal enabledelayedexpansion
echo.

set tmpScript=script.bat
:: used when switching git branches
IF not "%~nx0"=="%tmpScript%" (
	copy /b/v/y %~nx0 %tmpScript%
	call %tmpScript%
	exit /b
)

:test
REM place test code here
REM pause
REM exit/b

:welcome
echo # Welcome to vanilla-diff!
echo # --------------------------
echo # This script will help you generate a readable log of mod changes
echo # that override vanilla files, called a diff file.
echo #
:help
echo # Usage:
echo #   ^<command^> [--^<option^>]
echo #
echo # Options:
echo #   keep-files   - Skip repository cleanup
echo #   no-update    - Don't update vanilla files
echo #
echo # Commands:
echo #   generate   - Generate a new vanilla diff file.
echo #   update     - Update vanilla files in root dir.
echo #   show       - Open diff or log file in terminal.
echo #   quit       - Stop script and return to terminal.
echo #   help       - Print list of commands and options.
:input
echo.
set "input="
set /p input="$ "
call :readInput %input%
IF "%command%"=="" ( goto input)
echo.
IF "%command%"=="generate" ( goto run )
IF "%command%"=="update" ( goto run )
IF "%command%"=="show" ( call :Show %option% )
IF "%command%"=="help" ( goto help )
IF "%command%"=="quit" ( exit /b )

echo Error: unknown command '%command%'
echo Call 'help' to show a list of usable commands.
goto input

:readInput
set command=%1
set option=%2
exit /b

:run
call :init
IF not "%option%"=="-no-update" (
	call :copyFiles
) else (
	echo Skipping file update.
)
IF "%command%"=="update" (
	goto input
)
IF "%option%"=="-no-update" (
	call :NoUpdate
)
call :trimFiles
call :createCommit
call :writeDiff
IF "%option%"=="-keep-files" (
	echo Skipping cleanup.
) else (
	call :cleanRepo
)
echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
goto input

:init
IF exist "error.log" del error.log

set fileSize=0

set this=%~nx0
set config="vanilla.ini"
set updateLog="update.log"
set buildLog="build.log"
set installLog="install.log"
set gitLog="git.log"

echo. > %buildLog%
echo Initialize process: >> %buildLog%
echo config file = %config% >> %buildLog%
echo update log = %updateLog% >> %buildLog%
echo build log = %buildLog% >> %buildLog%
echo install log = %installLog% >> %buildLog%
echo git log = %gitLog% >> %buildLog%

git diff HEAD > build.tmp
for /f %%i in ("build.tmp") do set fileSize=%%~zi
IF %fileSize% gtr 0 (
	echo Stashing changes in working directory...
	git add %this% > %gitLog%
	git add %config% >> %gitLog%
	git stash save --keep-index >> %gitLog%
	git diff HEAD > head.diff
	echo stashed changed, see 'git.log'. >> %buildLog%
	set fileSize=0
)
call :install
call :readIni
exit /b

:install
IF not EXIST "JREPL.BAT" (
	echo. >> %buildLog%
	echo Install dependencies. >> %buildLog%
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
echo. >> %buildLog%
echo Read configuration file: >> %buildLog%
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
echo gamePath = %gamePath% >> %buildLog%
echo txtFiles = %txtFiles% >> %buildLog%
exit /b

:copyFiles
echo. >> %buildLog%
echo Copy vanilla files: >> %buildLog%
echo Preparing to copy files...

echo Creating list of files on master branch...
git ls-tree -r master --name-only > master.diff
call jrepl "(\/)" "\" /f "master.diff" /o - >> %buildLog%

echo Adding localisation overrides to list...
@git checkout master >> %gitLog%
copy NUL replace.diff >> %buildLog%
for /r . %%a in (localisation\replace\*) do (
	echo localisation\%%~nxa >> master.diff
	echo localisation\%%~nxa >> replace.diff
)

set fileCategory=null
IF exist files.diff del files.diff >> %buildLog%
copy NUL files.diff >> %buildLog%

echo Copying override localisation files...
for /F "usebackq tokens=*" %%a in (replace.diff) do (
	call :CopyFile null %%~na%%~xa %%a
)
echo Creating override shell script...
IF NOT exist temp\ ( mkdir temp )
set /a c=0
for /r . %%a in (localisation\replace\*) do (
	echo override localisation: %%a >> %buildLog%
	for /f "tokens=*" %%b in (localisation\replace\%%~na%%~xa) do (
		set /a c=c+1
		echo. %%b> temp\override!c!.tmp
		call :AddOverrideToSH %%b "localisation\%%~na%%~xa"
	)
)
echo Applying overrides to localisation...
start E:\Programs\Git\git-bash.exe -i -c "bash override.sh"

echo Adding localisation changes to index...
for /F "usebackq tokens=*" %%a in (replace.diff) do (
	git add %%a >> %gitLog%
)
echo Recording changes to repository...
git commit -m "temp-localisation-replace" >> %gitLog%
git rev-parse HEAD > build.tmp
( set /p masterHEAD= ) < build.tmp
@git checkout vanilla >> %gitLog%

echo.
echo. > %updateLog%
for /F "usebackq tokens=*" %%a in (master.diff) do (
	echo %%a > build.tmp
	call jrepl "\\(.*(?:\\))?" " " /f "build.tmp" /o - >> %buildLog%
	for /F "usebackq tokens=*" %%b in (build.tmp) do (
		call :CopyFile %%b %%a
	)
)
echo.
echo Completed copying vanilla files!
echo Operation log saved in 'update.log'
exit /b

:trimFiles
echo. >> %buildLog%
echo Remove trailing space: >> %buildLog%
echo Trimming trailing space...
for /F "usebackq tokens=*" %%a in (files.diff) do (
	call :trimFile %%a
)
exit /b

:trimFile
for %%b in (%txtFiles%) do (
	IF "%~x1"=="%%b" (
		echo trim %1 >> %buildLog%
		call jrepl "\s+$" "" /x /f "%cd%\%1" /o - >> %buildLog%
		goto nextFileEntry
	)
)
echo skip %1 >> %buildLog%
:nextFileEntry
exit /b

:createCommit
echo. >> %buildLog%
echo.
echo Add file contents to index: >> %buildLog%
git config --global core.safecrlf false >> %gitLog%
echo Adding file contents to index...
git add * >> %gitLog%
git reset -- %this% >> %gitLog%
git reset -- %config% >> %gitLog%

git rev-parse HEAD > build.tmp
( set /p oldHEAD= ) < build.tmp

echo Recording changes to repository...
git commit -m "temp-vanilla-files" >> %gitLog%

git rev-parse HEAD > build.tmp
( set /p newHEAD= ) < build.tmp
IF "%oldHEAD%"=="%newHEAD%" (
	call :CTError 6
)
exit /b

:writeDiff
echo. >> %buildLog%
echo Generate diff file: >> %buildLog%
echo Writing diff to file...
git diff --diff-filter=M vanilla master > vanilla.diff
exit /b

:cleanRepo
echo. >> %buildLog%
echo Clean repository: >> %buildLog%
echo Cleaning repository...
git rev-parse HEAD > build.tmp
( set /p curHEAD= ) < build.tmp
IF "%curHEAD%"=="%vanillaHEAD%" (
	git reset --keep HEAD~ >> %gitLog%

) else (
	call :Error 4 %curHEAD% %vanillaHEAD%
)
git checkout master >> %gitLog%
git rev-parse HEAD > build.tmp
( set /p curHEAD= ) < build.tmp
IF "%curHead%"=="%masterHEAD%" (
	git reset --keep HEAD~ >> %gitLog%

) else (
	call :Error 4 %currHEAD% %masterHEAD%
)
git checkout vanilla >> %gitLog%
RMDIR /s /q temp
del build.tmp
exit /b

:NoUpdate
git diff --diff-filter=M vanilla master > test.tmp
for /f %%i in ("test.tmp") do set fileSize=%%~zi
:: no vanilla files found in root dir
IF not %fileSize% gtr 0 (
	set fileSize=0
	call :Error 7
	set "answer="
	call :Query "Do you wish to run an update?" answer
	echo.
	IF "!answer!"=="y" (
		call :copyFiles
		exit /b
	)
	IF "!answer!"=="n" (
		echo Aborting operation.
		goto input
	)
	call :CTError 8
)
exit /b

:AddOverrideToSH <key> <text> <file>

set key=%1
IF not x%key:l_english=%==x%key% ( exit /b )
set "tf=temp\override!c!.tmp"
set "awk='FNR==NR{s=s"\n"$0;next;} /%1 /{$0=substr(s,2);}"
echo awk %awk% 1' "%tf%" %3 ^> build.tmp ^&^& mv build.tmp %3 >> override.sh
exit /b

:CopyFile <path>
set fileDirName=%1
set filename=%2
set filePath=%3
call set filePath=%%filePath:\%filename%=%%

IF not "%fileCategory%"=="%1" (
	IF not "%fileDirName%"=="%filename%" (
		set fileCategory=%1
		echo Copying "%1" files...
	)
)
set src=%gamePath%\%filePath%
set dest=%cd%\%filePath%
IF exist "%src%\%filename%" (
	echo copy %3 >> %buildLog%
	robocopy "%src%" "%dest%" %filename% /IT >> %updateLog%
	:: Fill list of copied file paths
	echo %3 >> files.diff
)
exit /b

:Show <file>
IF "%1"=="" (
	call :Error 11
	goto input
)
set showFileExt=.log .diff
for %%a in (%showFileExt%) do (
	IF "%~x1"=="%%a" ( goto show-read )
)
call :Error 10 %1
goto input
:show-read
IF not exist "%1" (
	call :Error 9 %1
	goto input
)
for /f "tokens=*" %%a in (%1) do (
	IF "%%a"=="" (
		echo.
	) else ( echo %%a )
)
goto input

:Query <text> <output>
set "a="
set /p a="%~1 (y/n): "
set %2=%a%
IF "%a%"=="y" ( exit /b )
IF "%a%"=="n" ( exit /b )
goto Query

:Error <code> [<info>]

IF "%1"=="4" (
	echo Unexpected HEAD (%2), expected (%3).
	echo Something went wrong, skipping cleanup.
)
IF "%1"=="7" (
	echo.
	echo No vanilla files found in repository.
	echo Either running with 'no-update' or something went wrong.
)
IF "%1"=="9" (
	echo Unable to find file '%2' in root directory.
)
IF "%1"=="10" (
	echo '%2' is not a valid log or diff file.
)
IF "%1"=="11" (
	echo No file passed as argument.
	echo Use command like this: show ^<file^>
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
IF "%1"=="8" (
	echo Unable to read user input.
)
echo.
echo Critical error occured, aborting operation!
goto input

:EOF
pause