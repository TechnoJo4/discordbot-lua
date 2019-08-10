# discordbot-lua
Remake of another very old project of mine.
`lit install` to install dependencies.

Uses a `token` env variable, e.g.
```powershell
cd src
$env:token = "[TOKEN HERE]"
luvit ./main.lua
Remove-Item -Path env:token
cd ..
```