# discordbot-lua
Remake of another very old project of mine.

`lit install` to install dependencies, run `emmy/gen.lua` to generate EmmyLua annotations for discordia. 

The `token` env variable is used for authentication, e.g.
```powershell
cd src
$env:token = "[TOKEN HERE]"
luvit ./main.lua
Remove-Item -Path env:token
cd ..
```