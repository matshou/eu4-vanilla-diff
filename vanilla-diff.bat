@ECHO off
setlocal enabledelayedexpansion

:: define config files here
set config=vanilla.ini
set updateLog=update.log
set buildLog=build.log
set installLog=install.log
set errorLog=error.log
set gitLog=git.log

set fileSize=0
set t1=0
set t2=0

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
	call :GetFileSize head.diff
	IF !fileSize! gtr 0 (
		(echo. & echo $ git stash pop) >> %gitLog%
		git stash pop 1>> %gitLog% 2>> %errorLog%
	)
	echo remove temp dir >> %buildLog%
	RMDIR /s /q temp
	echo remove shell dir >> %buildLog%
	RMDIR /s /q shell
	REM pause
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
call :copyFiles
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

call :GetNewTmp build

set /a seed=%RANDOM% * 1000 / 32768 + 1
set stash_id=%seed%

:: create log files
copy NUL %buildLog% > nul
copy NUL %updateLog% > nul
copy NUL %errorLog% > nul
copy NUL %gitLog% > nul

call :PrintHeader "Initialize process:" 19 %buildLog%
echo config file = %config% >> %buildLog%
echo update log = %updateLog% >> %buildLog%
echo build log = %buildLog% >> %buildLog%
echo install log = %installLog% >> %buildLog%
echo error log = %errorLog% >> %buildLog%
echo git log = %gitLog% >> %buildLog%

:: create temporary config file
:: so it doesn't get deleted on checkout
copy %config% temp\%config% > nul
set config=temp\%config%

:: stash local changes
call :GitStash "wip" --keep-index

:: suppress CRLF warnings
call :Git config --local core.safecrlf %safecrlf%

call :install
echo Loading configuration values...
call :PrintHeader "Read configuration file:" 24 %buildLog%
IF not EXIST %config% (
	echo Missing config file, update your local repository.
	call :CTError
)
for /F "usebackq tokens=*" %%a in (%config%) do (
	call :ReadConfig %%a
)
IF not EXIST "%gamePath%\eu4.exe" (
	echo Couldn't find 'eu4.exe' in %gamePath%.
	echo Make sure that 'gamePath' entry in 'vanilla.ini' points to game directory.
	call :CTError
)
IF not EXIST "%gitBashPath%" (
	echo. & echo Git Bash not installed!
	echo Make sure that 'gitBashPath' config points to a MinGW executable.
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
	IF not EXIST "JREPL.BAT" (
		echo Unable to install JREPL, read 'install.log' for more info.
		call :CTError
	)
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
	call :CopyFile %%a
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
	call :CopyFile %%a
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
	echo Failed to commit changes, read 'build.log' for more info.
	call :CTError
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
exit /b


:::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::: Task Subroutines ::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::

:RunCommand <command>
FOR /F "tokens=*" %%i in ('%*') do SET output=%%i
exit /b

:GetFileSize <file>
set fileSize=0
for /f %%i in ("%~1") do set fileSize=%%~zi
exit /b

:Git <command>
(echo. & echo $ git %*) >> %gitLog%
git %* 1>> %gitLog% 2>> %errorLog%
exit /b

:GitStash <message> [<args>]
set /a stash_id=%stash_id%+1
git diff HEAD > head.diff
call :GetFileSize head.diff
IF %fileSize% gtr 0 (
	echo Stashing changes in working directory...
	call :Git stash push %~2 -m "vanilla-diff %~1 %stash_id%"
	echo stashed changed, see 'head.diff'. >> %buildLog%
	git stash show >> %gitLog%
)
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
echo !%1! ^> !%3! >> shell\%2
exit /b

:RunShellScript <command>
start /wait %gitBashPath% -i -c "bash shell/%1"
exit /b

:ReadConfig <entry> <value>
FOR /F "tokens=1-2 delims==" %%I IN ("%*") DO (
	set value=%%~J
	:: parse list config entries
	IF "!value!"=="%%J" (
		set value=!value:,= !
	)
	set %%I=!value!
	echo %%I = %%J >> %buildLog%
)
exit /b

:GetSubstring <input> <replace> <regex> <rules> <output>
set "cmd=echo !%~1!^^|jrepl . %2 /p %3 /prepl %4"
FOR /F "tokens=*" %%i in ('%cmd%') do SET %5=%%i
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
set xpathx=%1
set filename=%~nx1
set filepath=!xpathx:\%~nx1=!
IF not "%filepath%"=="%xpathx%" (
	for /F "tokens=1 delims=\" %%b in ("%filepath%") do (
		IF not "%fileCategory%"=="%%b" (
			set fileCategory=%%b
			echo Copying "%%b" files...
		)
	)
)
set src=%gamePath%\%filepath%
set dest=%cd%\%filepath%
set fullpath=%src%\%filename%

IF exist "%fullpath%" (
	echo copy %fullpath% >> %buildLog%
	robocopy "%src%" "%dest%" %filename% /IT >> %updateLog%
	:: Fill list of copied file paths
	echo %1 >> files.diff
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

:CTError
echo. & echo Critical error occured, aborting operation!
set _errLevel=%1
REM *** Remove all calls from the current batch from the call stack
:popStack
(
    (goto) 2>nul
    setlocal DisableDelayedExpansion
    call set "caller=%%~0"
    call set _caller=%%caller:~0,1%%
    call set _caller=%%_caller::=%%
    if not defined _caller (
        REM callType = func
        rem set _errLevel=%_errLevel%
        goto :popStack
    )
    (goto) 2>nul
    endlocal
    cmd /c "exit /b %_errLevel%"
)
exit /b
