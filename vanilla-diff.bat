@ECHO off
setlocal enabledelayedexpansion

:: set only for main script process
IF not DEFINED vanillaDiff (
	set vanillaDiff=%~nx0
)
set tmpScript=script.bat
:: used when switching git branches
IF not "%~nx0"=="%tmpScript%" (
	@copy /b/v/y %~nx0 %tmpScript% > nul
	call %tmpScript%

	@del %tmpScript%
	IF "%stashed%"=="true" (
		(echo. & echo $ git stash pop) >> %gitLog%
		git stash pop >> %gitLog%
	)
	exit /b
)

:test
REM place test code here
REM pause
REM exit/b

call :init
echo.

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
echo #   update     - Update application from remote repo.
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
IF "%command%"=="show" ( call :Show %option% )
IF "%command%"=="help" ( goto help )
IF "%command%"=="quit" ( exit /b )

IF "%command%"=="update" (
	echo Updating vanilla-diff...
	call :Git pull !repoURL!
	goto input
)

echo Error: unknown command '%command%'
echo Call 'help' to show a list of usable commands.
goto input

:readInput
set command=%1
set option=%2
exit /b

:run
IF not "%option%"=="-no-update" (
	call :copyFiles
) else (
	echo Skipping file update.
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
echo. & echo Finished generating diff file!
echo See 'vanilla.diff'
goto input

:init
echo. & echo Initializing application...
IF exist "error.log" del error.log
IF NOT exist temp\ ( mkdir temp )
IF NOT exist shell\ ( mkdir shell )

set fileSize=0      rem temp file size
set t1=0            rem override temp prefix
set t2=0            rem build temp prefix

call :GetNewTmp build

set config=vanilla.ini
set updateLog=update.log
set buildLog=build.log
set installLog=install.log
set gitLog=git.log

set /a seed=%RANDOM% * 1000 / 32768 + 1
set stash_id=%seed%
set stashed=false

:: create log files
copy NUL %buildLog% > nul
copy NUL %updateLog% > nul
copy NUL %gitLog% > nul

call :PrintHeader "Initialize process:" 19 %buildLog%
echo config file = %config% >> %buildLog%
echo update log = %updateLog% >> %buildLog%
echo build log = %buildLog% >> %buildLog%
echo install log = %installLog% >> %buildLog%
echo git log = %gitLog% >> %buildLog%

git diff HEAD > %build_tmp%
for /f %%i in ("%build_tmp%") do set fileSize=%%~zi
IF %fileSize% gtr 0 (
	echo Stashing changes in working directory...
	rem add dependencies to index
	rem :::::::::::::::::::::::::
	call :Git add %config%
	rem :::::::::::::::::::::::::
	call :GitStash "wip" --keep-index
	IF not ERRORLEVEL 1 (
		set stashed=true
	)
	copy %build_tmp% head.diff > nul
	echo stashed changed, see 'head.diff'. >> %buildLog%
	set fileSize=0
)

:: suppress CRLF warnings
call :Git config --local core.safecrlf %safecrlf%

call :install
echo Loading configuration values...
call :PrintHeader "Read configuration file:" 24 %buildLog%
IF not EXIST %config% ( call :CTError 1 )
for /F "usebackq tokens=*" %%a in (%config%) do (
	call :ReadConfig %%a
)
IF not EXIST "%gamePath%\eu4.exe" (
	echo Couldn't find 'eu4.exe' in %gamePath%.
	echo Make sure that 'gamePath' entry in 'vanilla.ini' points to game directory.
	call :CTError
)
exit /b

:install
IF not EXIST "JREPL.BAT" (
	echo. & echo Install dependencies. >> %buildLog%
	echo Regex text processor not found.
	echo Downloading and installing...
	echo download jrepl >> %buildLog%
	powershell -Command "(New-Object Net.WebClient).DownloadFile('https://www.dostips.com/forum/download/file.php?id=390&sid=3bb47c363d95b5427d516ce1605df600', 'JREPL.zip')" > %installLog%
	echo extract package >> %buildLog%
	7z e -aoa JREPL.zip >> %installLog%
	del JREPL.zip >> %installLog%
	IF not EXIST "JREPL.BAT" ( call :CTError 5 )
	echo Finished installing JREPL.
	del %installLog%
)
exit /b

:copyFiles
call :PrintHeader "Copy vanilla files:" 19 %buildLog%
echo Preparing to copy files...

echo Creating list of files on master branch...
git ls-tree -r master --name-only > master.diff
call jrepl "(\/)" "\" /f "master.diff" /o - >> %buildLog%

echo Adding localisation overrides to list...

call :Checkout master

@copy NUL replace.diff > nul
for /r . %%a in (localisation\replace\*) do (
	echo localisation\%%~nxa >> master.diff
	echo localisation\%%~nxa >> replace.diff
)

set fileCategory=null
IF exist files.diff del files.diff >> %buildLog%
@copy NUL files.diff > nul

echo. & echo Copying override localisation files...
for /F "usebackq tokens=*" %%a in (replace.diff) do (
	call :CopyFile null %%~na%%~xa %%a
)
echo Creating override shell script...
for /r . %%a in (localisation\replace\*) do (
	echo override localisation\replace\%%~na%%~xa >> %buildLog%
	for /f "tokens=*" %%b in (localisation\replace\%%~na%%~xa) do (
		call :AddOverride %%b "localisation\%%~na%%~xa"
	)
)
echo Applying overrides to localisation...
call :RunShellScript override.sh

echo Adding localisation changes to index...
for /F "usebackq tokens=*" %%a in (replace.diff) do (
	call :Git add %%a
)
echo Recording changes to repository...
call :Git commit -m "temp-localisation-replace"
git rev-parse HEAD > %build_tmp%
( set /p masterHEAD= ) < %build_tmp%

call :Checkout vanilla

echo.
for /F "usebackq tokens=*" %%a in (master.diff) do (
	echo %%a > %build_tmp%
	call jrepl "\\(.*(?:\\))?" " " /f "%build_tmp%" /o - >> %buildLog%
	for /F "usebackq tokens=*" %%b in (%build_tmp%) do (
		call :CopyFile %%b %%a
	)
)
echo. & echo Completed copying vanilla files!
echo Operation log saved in 'update.log'
exit /b

:trimFiles
call :PrintHeader "Remove trailing space:" 22 %buildLog%
echo. & echo Trimming trailing space...
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
call :PrintHeader "Add file contents to index:" 27 %buildLog%
echo Adding file contents to index...
call :Git add *
call :Git reset -- %vanillaDiff%
call :Git reset -- %config%

git rev-parse HEAD > %build_tmp%
( set /p curHEAD= ) < %build_tmp%

echo do commit "temp-vanilla-files" >> %buildLog%
echo Recording changes to repository...
call :Git commit -m "temp-vanilla-files"

git rev-parse HEAD > %build_tmp%
( set /p vanillaHEAD= ) < %build_tmp%

echo commit SHA: %vanillaHEAD% >> %buildLog%
IF "%curHEAD%"=="%vanillaHEAD%" (
	call :CTError 6
)
exit /b

:writeDiff
call :PrintHeader "Generate diff file:" 19 %buildLog%
echo Writing diff to file...
for /F "usebackq tokens=*" %%a in (.diffignore) do (
	set "exclude=!exclude! ^':^(exclude^)%%a^'"
)
set "shCommand=git diff --diff-filter=M vanilla master %exclude%"
call :RunBash shCommand diff.sh vanilla.diff
exit /b

:cleanRepo
call :PrintHeader "Clean repository:" 17 %buildLog%
echo Cleaning repository...
git rev-parse HEAD > %build_tmp%
( set /p curHEAD= ) < %build_tmp%
IF "%curHEAD%"=="%vanillaHEAD%" (
	echo reset vanilla HEAD >> %buildLog%
	call :Git reset --keep HEAD~

) else (
	call :Error 4 %curHEAD% %vanillaHEAD%
)
call :Checkout master
git rev-parse HEAD > %build_tmp%
( set /p curHEAD= ) < %build_tmp%
IF "%curHEAD%"=="%masterHEAD%" (
	echo reset master HEAD >> %buildLog%
	call :Git reset --keep HEAD~

) else (
	call :Error 4 %currHEAD% %masterHEAD%
)
call :Checkout vanilla
echo remove temp dir >> %buildLog%
RMDIR /s /q temp
echo remove shell dir >> %buildLog%
RMDIR /s /q shell
exit /b


:::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::

:RunCommand <command>
FOR /F "tokens=*" %%i in ('%*') do SET output=%%i
exit /b

:: use § as a replacement token for text
:: ex. call :Git stash "save §" "vanilla-diff wip"
:Git <command>
(echo. & echo $ git %*) >> %gitLog%
git %* >> %gitLog%
exit /b

:GitStash <message> [<args>]
set /a stash_id=%stash_id%+1
git diff HEAD > git.tmp
call :GetFileSize git.tmp
IF %fileSize% gtr 0 (
	call :Git stash push %~2 -m "vanilla-diff %~1 %stash_id%"
	git stash show >> %gitLog%
	exit /b
)
exit /b 1

:GetFileSize <file>
set fileSize=0
for /f %%i in ("%~1") do set fileSize=%%~zi
exit /b

:RunBash <command> <name> <output>
call :CreateShellScript "!%1!" %2 %3
echo execute shell command: "!%1!" >> %buildLog%
call :RunShellScript %2
exit /b

:CreateShellScript <command> <name> <output>
echo create new shell script: %2 ^/o %~3 >> %buildLog%
echo %~1 ^> %~3 > shell\%2
exit /b

:AppendToShellScript <command> <name> <output>
REM echo append command to shell script %2: !%1! >> %buildLog%
echo !%1! ^> !%3! >> shell\%2
exit /b

:RunShellScript <command>
start /wait %gitBashPath% -i -c "bash shell/%1"
exit /b

:Checkout <branch>
call :GetCurrentBranch old_branch
call :Git checkout %1 --quiet
call :GetCurrentBranch new_branch
IF "%old_branch%"=="%new_branch%" (
	echo Unable to checkout to '%1'
	echo Something went wrong, read 'git.log' for more info.
	call :CTError
)
exit /b

:GetCurrentBranch <output>
call :RunCommand git rev-parse --abbrev-ref HEAD
set %1=%output%
exit /b

:ReadConfig <entry> <value>
FOR /F "tokens=1-2 delims==" %%I IN ("%*") DO (
	set value=%%~J
	IF "%%I"=="txtFiles" (
		call :ParseConfigValue "%%J" value
	)
	set %%I=!value!
	echo %%I = %%J >> %buildLog%
)
exit /b

:ParseConfigValue
set values=%~1
call jrepl "," " " /s values > %build_tmp%
( set /p values= ) < %build_tmp%
set %2=%values%
exit /b

:GetNewTmp <type>
IF "%1"=="override" (
	set /a t1=t1+1
	set override_tmp=temp\override!t1!.tmp
)
IF "%1"=="build" (
	set /a t2=t2+1
	set build_tmp=temp\build!t2!.tmp
)
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

:AddOverride <key> <text> <file>
set key=%1
IF not x%key:l_english=%==x%key% ( exit /b )

call :GetNewTmp override
echo. %1 %2> !override_tmp!

set "shCommand=awk 'FNR==NR{s=s"\n"$0;next;} /%1 /{$0=substr(s,2);} 1' "!override_tmp!" %3"
set "output=!build_tmp! ^&^& mv !build_tmp! %3"
call :AppendToShellScript shCommand override.sh output
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

:PrintHeader <text> <length> <output>
set separator=
for /L %%a in (1,1,%2) do (
	set separator=!separator!-
)
(echo. & echo %~1 & echo %separator%) >> %3
exit /b

:Error <code> [<info>]

IF "%1"=="4" (
	echo Unexpected HEAD (%2), expected (%3).
	echo Something went wrong, skipping cleanup.
)
IF "%1"=="7" (
	echo. & echo No vanilla files found in repository.
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
echo. & echo Critical error occured, aborting operation!
goto input

:EOF
pause