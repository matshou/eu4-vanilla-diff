## About
`vanilla-diff` is a small modding utility batch script for Europa Universalis IV. It will help you generate a readable log of mod changes that
override vanilla files, called a diff file that can then be opened and viewed with any text editor.

## Requirements
- Modern Windows operating system.
- Git version 2.x with bash integrated in Windows explorer.
- Text editor that can properly parse diff files like Notepad++.

## Instructions
- Make sure Git is added to your PATH. You can check this by running `git version` command in cmd. If you get an error that Git is not a recognized command, you need to either reinstall Git with `Use Git from the Windows Command Prompt` option selected or manually adjust your PATH environment.

## Install
Create a new orphan branch called `vanilla` in your mod repo then pull from `eu4-vanilla-diff`.
```
git checkout --orphan vanilla
git reset --hard
git pull https://github.com/yooksi/eu4-vanilla-diff
```
## Uninstall
Simply delete `vanilla` branch on local and remote _(if repo is hosted)_.
```
git push origin --delete vanilla
git branch -D vanilla
```