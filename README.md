# StyxScribe
Allows plugins to hook into Hades or Pyre and listen for output and to send input in.

The input is queued up until it's read by by the game at a certain interval, but the output is instantly captured.

For example plugins look at the [REPL](Content/Mods/StyxScribeREPL) or the [shared state](Content/Mods/StyxScribeShared)

* Requires [modimporter](https://github.com/SGG-Modding/sgg-mod-modimporter) to install the plugins.
* Requires [ModUtil](https://github.com/SGG-Modding/sgg-mod-modutil) to run the lua side

## Instructions

* place this repo's contents directly into your Hades or Pyre folder    
* (if on mac move the `Content` folder to `Contents/Resources/Content`)  
* run `modimporter` in the `Content` folder 
* run `subsume_hades.py` or `subsume_pyre.py` to run the game with the scribe attached
* load a save in Hades (or merely let the main menu open in Pyre), so the lua begins `Polling...`

## Plugins

Plugins are in the [importable format](https://github.com/SGG-Modding/sgg-mod-format).  

To add a lua script to be loaded add
```
Import "myscript.lua"
```
to the start of your `modfile.txt`

The lua script can interface with the `StyxScribe` global to hook into when messages get sent into the game:
```lua
ModUtil.Mod.Register("MyMod")

-- prefix for communicating over a channel
local prefix = "MyMod: Message: "
local function callback( message )
    -- do something with the message
    -- the message will have the prefix removed already

    -- example: sending back the same message
    print( prefix .. message )
end

-- listen for messages that start with a given prefix
StyxScribe.AddHook( callback, prefix, MyMod )
```

To add a python script to be loaded by the scribe add
```
To "StyxScribeScripts/myscript.py"
Replace "myscript.py"
```
to the end of your `modfile.txt`

The python script (inside the `load` or `callback` global function) can interface with the `scribe` global:
```py
# prefix for communicating over a channel
prefix = "MyMod: Message: "
def callback( message ):
    # do something with the message
    # the message will have the prefix removed already

    # example: sending back the same message
    scribe.send( prefix + message )
```
or
```py
def load( ):
    # prefix for communicating over a channel
    prefix = "MyMod: Message: "
    def callback( message ):
        # do something with the message
        # the message will have the prefix removed already

        # example: sending back the same message
        scribe.send( prefix + message )
    scribe.add_hook( callback, prefix, __name__ )
```

You can access all the loaded modules from `scribe.modules`

### REPL

Turns the output console into a lua and python REPL

to use the python REPL, prefix your message with `>`
```
>(1,2)
(1, 2)
```
in the python REPL you can access all the modules via `scribe.modules`    
>   example:    `scribe.modules.StyxScribeShared`     

you can send code to be executed lua side using the function `run_lua`

to use the lua REPL, don't prefix your message with `>`
```
1,2
Out: 1  2
```
in the lua REPL you can access all the mods by their global namespace
>   example:    `ModUtil`     

To immediately exit both the game and terminal, type `>end()`

### Shared State

Adds some shared state between the python and the game's lua in the form of a new type of object that communicates implicitly.

* Lua: `StyxScribe.Shared`
* Python: `scribe.shared`

using the [REPL](#REPL) to demonstrate:
```
StyxScribe.Shared.Health = CurrentRun.Hero.Health
CurrentRun.Hero.Health
Out: 100
>scribe.shared["Health"] += 15
StyxScribe.Shared.Health
Out: 115
```

you can create new shared objects:

```
>scribe.shared
{}
ModUtil.ToString.Deep( StyxScribe.Shared )
Out: "<table:1E0AB8E2750>( )"
>scribe.shared["A"] = scribe.shared()
>scribe.shared
{'A': {}}
ModUtil.ToString.Deep( StyxScribe.Shared )
Out: "<table:1E0AB8E2750>( A = <table:1E13A479AA0>(  ) )"
StyxScribe.Shared.A.B = StyxScribe.Shared( )
>scribe.shared
{'A': {'B': {}}}
```

## Videos

[<img src="https://cdn.cloudflare.steamstatic.com/steam/apps/1145360/header.jpg?t=1624463563" width="50%">](https://cdn.discordapp.com/attachments/770267934231625728/929358733514006548/2022-01-08_23-55-58.mp4)

[<img src="https://cdn.cloudflare.steamstatic.com/steam/apps/462770/header.jpg?t=1601500944" width="50%">](https://cdn.discordapp.com/attachments/770267934231625728/929358732322799626/2022-01-08_23-50-38.mp4)
