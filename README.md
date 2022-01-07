# HadesListener
Allows plugins to hook into Hades and listen for output and to send input in.

The input is queued up until it's read by by the game at a certain interval, but the output is instantly captured.

For example plugins look at the [REPL](Content/Mods/HadesListenerREPL) or the [shared state](Content/Mods/HadesListenerShared)

* Requires [modimporter](sgg-mod-modimporter) to install the plugins.
* Requires [ModUtil](sgg-mod-modutil) to run the lua side

## Instructions

* place this repo's contents directly into your Hades folder    
* (if on mac move the `Content` folder to `Contents/Resources/Content`)  
* run `modimporter` in the `Content` folder 
* run `subsume.py` to run the game with the listener attached
* load a save so the lua begins `Polling...`

## Plugins

Plugins are in the [importable format](sgg-mod-format).  

To add a lua script to be loaded add
```
Import "myscript.lua"
```
to the start of your `modfile.txt`

The lua script can interface with the `HadesListener` global to hook into when messages get sent into the game:
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
HadesListener.AddHook( callback, prefix, MyMod )
```

To add a python script to be loaded by the listener add
```
To "HadesListenerPlugins/myscript.py"
Replace "myscript.py"
```
to the end of your `modfile.txt`

The python script (inside the `load` or `callback` global function) can interface with the `listener` global:
```py
# prefix for communicating over a channel
prefix = "MyMod: Message: "
def callback( message ):
    # do something with the message
    # the message will have the prefix removed already

    # example: sending back the same message
    listener.send( prefix + message )
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
        listener.send( prefix + message )
    listener.add_hook( callback, prefix, __name__ )
```

### REPL

Turns the output console into a lua and python REPL

to use the python REPL, prefix your message with `>`
```
>(1,2)
(1, 2)
```
in the python REPL you can access all the modules via `listener.modules`    
>   example:    `listener.modules.hades_listener`     

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

* Lua: `HadesListener.Shared`
* Python: `listener.shared`

using the [REPL](#REPL) to demonstrate:
```
HadesListener.Shared.Health = CurrentRun.Hero.Health
CurrentRun.Hero.Health
Out: 100
>listener.shared["Health"] += 15
HadesListener.Shared.Health
Out: 115
```

you can create new shared objects:

```
>listener.shared
{}
ModUtil.ToString.Deep( HadesListener.Shared )
Out: <table:1E0AB8E2750>( )
>listener.shared["A"] = listener.shared()
>listener.shared
{'A': {}}
ModUtil.ToString.Deep( HadesListener.Shared )
Out: <table:1E0AB8E2750>( A = <table:1E13A479AA0>(  ) )
HadesListener.Shared.A.B = HadesListener.Shared( )
>listener.shared
{'A': {'B': {}}}
```
