# discordbot-lua

## Running

Assuming you have luvit installed, run `lit install` to install dependencies.

The `token` environment variable is used for authentication.

You can use a script like the below powershell to easily start the bot.

```powershell
cd src
$env:token = "[TOKEN HERE]"
luvit ./main.lua
Remove-Item -Path env:token
cd ..
```

Use the `shutdown` command to shutdown the bot. DO NOT terminate the process or, in a terminal, use Ctrl+C.
Improper shutdown of the bot can and will likely cause to loss of data.

## Configuration

You can change the constants at the beginning of `src/main.lua`.

You can temporarily disable modules by adding `do return false end` at the start of the file.

## Development

Run `emmy/gen.lua` to generate EmmyLua annotations for discordia. 
