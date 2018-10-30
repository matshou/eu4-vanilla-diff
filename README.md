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