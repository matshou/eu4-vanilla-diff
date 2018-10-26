@ECHO off
setlocal
echo.

IF exist "error.log" del error.log

set config="vanilla.ini"
set updateLog="update.log"
set buildLog="build.log"
set installLog="install.log"

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

:readIni
IF not EXIST %config% ( call :CTError 1 )
(
set /p entry1=
set /p gamePath=
set /p entry2=
set /p fileList=
) < %config%

IF not "%entry1%"=="gamePath =" ( call :CTError 2 gamePath )
IF not "%entry2%"=="fileList =" ( call :CTError 2 fileList )

set gamePath=%gamePath:"=%
IF not EXIST "%gamePath%\eu4.exe" ( call :CTError 3 gamePath )

:copyFiles
echo Copy vanilla files from game directory:
echo.
echo. > %updateLog%
for %%a in (%fileList%) do ( CALL :CopyFile %%a )
echo.
echo Completed copying vanilla files!
echo Operation log saved in 'update.log'
echo.

:createCommit
echo Prepare to create diff file:
echo.
git config --global core.safecrlf false > %buildLog%
echo Adding file contents to index...
git add * >> %buildLog%
echo Recording changes to repository...
git commit -m "temp-vanilla-files" >> %buildLog%

:trimDiff
echo Compiling a list of changed vanilla files...
git diff --diff-filter=M --name-only master vanilla > names.diff

REM translate path separator from git(slash) to bash(backslash)
call :FindReplace "/" "\" names.diff

echo Trimming trailing space...
for /F "usebackq tokens=*" %%A in (names.diff) do (
	call jrepl "\s+$" "" /f "%rootPath%\%%A" /o - >> trim.log
)

:writeDiff
echo Writing diff to file...
git diff --diff-filter=M master vanilla > vanilla.diff

:cleanRepo <arg>
IF not "%1"=="--no-reset" (
	echo Resetting repository head...
	git reset HEAD~ >> %buildLog%
)
echo Cleaning repository...
git stash save --keep-index --include-untracked >> %buildLog%
git stash drop >> %buildLog%

:finish
echo.
echo Finished generating diff file!
echo See 'vanilla.diff'
echo.

pause
goto EOF

:FindReplace <findstr> <replstr> <file>
set tmp="%temp%\tmp.txt"
If not exist %temp%\_.vbs call :MakeReplace
for /f "tokens=*" %%a in ('dir "%3" /s /b /a-d /on') do (
  for /f "usebackq" %%b in (`Findstr /mic:"%~1" "%%a"`) do (
    REM echo(&Echo Replacing "%~1" with "%~2" in file %%~nxa
    <%%a cscript //nologo %temp%\_.vbs "%~1" "%~2">%tmp%
    if exist %tmp% move /Y %tmp% "%%~dpnxa">nul
  )
)
del %temp%\_.vbs
exit /b

:MakeReplace
>%temp%\_.vbs echo with Wscript
>>%temp%\_.vbs echo set args=.arguments
>>%temp%\_.vbs echo .StdOut.Write _
>>%temp%\_.vbs echo Replace(.StdIn.ReadAll,args(0),args(1),1,-1,1)
>>%temp%\_.vbs echo end with


:CopyFile
set targetDir=%1
echo Copying %targetDir% files...
set src=%gamePath%\%targetDir%
set dest=%cd%\%targetDir%
IF exist "%src%" (
	robocopy /s "%src%" "%dest%" /IT >> %updateLog%
) else (
	call :Error 4 %targetDir%
)
exit /b

:Error <code> [<info>]

IF "%1"=="4" (
	echo Unable to find %2 in game directory! >> error.log
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
echo.
echo Critical error occured, aborting operation!
pause
exit

:EOF