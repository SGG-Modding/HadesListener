"""
Magic_Gonads (Discord: Magic_Gonads#7347)
Museus (Discord: Museus#7777)
"""
from collections import defaultdict
import os
import platform
import pathlib
import pkgutil
import importlib.util
import contextlib
from subprocess import Popen, PIPE, STDOUT

# Do not include extension
EXECUTABLE_NAME = "Hades"
# Do not include leading character (/ or -)
EXECUTABLE_ARGS = ["DebugDraw=true", "DebugKeysEnabled=true"]
PLUGIN_SUBPATH = "HadesListenerPlugins"
LUA_PROXY_STDIN = "proxy_stdin.txt"
LUA_PROXY_FALSE = "proxy_first.txt"
LUA_PROXY_TRUE = "proxy_second.txt"
PROXY_LOADED_PREFIX = "HadesListener: ACK"
INTERNAL_IGNORE_PREFIX = PROXY_LOADED_PREFIX

class HadesListener:
    """
    Used to launch Hades with a wrapper that listens for specified patterns.
    Calls any functions that are added via `add_hook` when patterns are detected.
    """

    def __init__(self):
        if platform.system() != "Darwin":
            self.executable_purepath = (
                pathlib.PurePath() / "x64" / f"{EXECUTABLE_NAME}.exe"
            )
            self.args = [f"/{arg}" for arg in EXECUTABLE_ARGS]
            self.plugins_paths = [str(
                pathlib.PurePath() / "Content" / PLUGIN_SUBPATH
            )]
        else:
            self.executable_purepath = pathlib.PurePath() / EXECUTABLE_NAME
            self.args = [f"-{arg}" for arg in executable_args]
            self.plugins_paths = [str(
                pathlib.PurePath() / "Contents/Resources/Content" / PLUGIN_SUBPATH
            )]

        self.proxy_purepaths = {
            None: self.executable_purepath.parent / LUA_PROXY_STDIN,
            False: self.executable_purepath.parent / LUA_PROXY_FALSE,
            True: self.executable_purepath.parent / LUA_PROXY_TRUE
        }
        
        self.args.insert(0, self.executable_purepath)
        self.hooks = defaultdict(list)

    def launch(self,echo=True):
        """
        Launch Hades and listen for patterns in self.hooks
        """
        if echo:
            print(f"Running {self.args[0]} with arguments: {self.args[1:]}")

        proxy_switch = False

        def sane(message):
            return f"[===[{message}]===]"

        def quick_write_file(path, content):
            with open(path, 'w', encoding="utf8") as file:
                file.write(content)

        def setup_proxies(swap=False):
            nonlocal proxy_switch
            quick_write_file(self.proxy_purepaths[None], f"print({sane(PROXY_LOADED_PREFIX)});return {sane(self.proxy_purepaths[proxy_switch].name)},0.05")
            if swap:
                proxy_switch = not proxy_switch
            with contextlib.suppress(FileNotFoundError):
                os.remove(self.proxy_purepaths[not proxy_switch])
            quick_write_file(self.proxy_purepaths[proxy_switch], f"print({sane(PROXY_LOADED_PREFIX)});return {sane(self.proxy_purepaths[not proxy_switch].name)},0.05")

        def send(message):
            with open(self.proxy_purepaths[proxy_switch], 'a', encoding="utf8") as file:
                if echo:
                    print(f"In: {message}")
                file.write(f",{sane(message)}")

        with open("out.txt", 'w', encoding="utf8") as out:

            setup_proxies()
                
            game = Popen(
                self.args,
                cwd=self.executable_purepath.parent,
                stdout=PIPE,
                stderr=STDOUT,
                universal_newlines=True,
                encoding="utf8",
            )

            while game.poll() is None:
                output = game.stdout.readline()
                if not output:
                    break
                output = output[:-1]
                if not output.startswith(INTERNAL_IGNORE_PREFIX):
                    if echo:
                        print(f"Out: {output}")
                    print(output, file=out)

                if output.startswith(PROXY_LOADED_PREFIX):
                    setup_proxies(True)

                for key, hooks in self.hooks.items():
                    if output.startswith(key):
                        for hook in hooks:
                            hook(output[len(key):], lambda s: send(f"{key}{s}"))

        with contextlib.suppress(FileNotFoundError):
            for path in self.proxy_purepaths.values():
                os.remove(path)

    def add_hook(self, callback, prefix="", source=None):
        """Add a target function to be called when pattern is detected

        Parameters
        ----------
        callback : function
            function to call when pattern is detected
        prefix : str
            pattern to look for at the start of lines in stdout
        """
        if callback in self.hooks[prefix]:
            return  # Function already hooked
        if not callable(callback):
            if source is not None:
                raise TypeError("Callback must be callable, blame {source}.")
            else:
                raise TypeError("Callback must be callable.")
        self.hooks[prefix].append(callback)
        if source is not None:
            callback = f"{callback} from {source}"
        print(f"Adding hook on \"{prefix}\" with {callback}")

    def load_plugins(self):
        for module_finder, name, _ in pkgutil.iter_modules(self.plugins_paths):
            spec = module_finder.find_spec(name)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            if hasattr(module, "load"):
                module.load(self)
            else:
                self.add_hook(module.callback, getattr(module, "prefix", ""), name)
