# discordbot-lua
Remake of another very old project of mine.
`lit install` to install dependencies.
Run `emmy/gen.lua` to generate annotations for EmmyLua (I use vscode & `sumneko.lua`, which supports EmmyLua annotations). 

Uses a `token` env variable, e.g.
```powershell
cd src
$env:token = "[TOKEN HERE]"
luvit ./main.lua
Remove-Item -Path env:token
cd ..
```