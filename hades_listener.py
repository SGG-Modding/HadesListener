"""
Museus (Discord: Museus#7777)
Based on subsume.py made by Magic_Gonads (Discord: Magic_Gonads#7347)
"""
from collections import defaultdict
import os
import pathlib
import pkgutil
import importlib.util
from subprocess import Popen, PIPE, STDOUT

# Do not include extension
EXECUTABLE_NAME = "Hades"
# Prefix to check for in output from Hades
FILTER_TOKEN = "$: "
# Do not include leading character (/ or -)
EXECUTABLE_ARGS = ["DebugDraw=true", "DebugKeysEnabled=true"]
PLUGIN_SUBPATH = "HadesListenerPlugins"


class HadesListener:
    """
    Used to launch Hades with a wrapper that listens for specified patterns.
    Calls any functions that are added via `add_hook` when patterns are detected.
    """

    def __init__(self):
        if os.name == "nt":
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

        self.args.insert(0, self.executable_purepath)

        self.hooks = defaultdict(list)

    def launch(self,echo=True):
        """
        Launch Hades and listen for patterns in self.hooks
        """
        if echo:
            print(f"Running {self.args[0]} with arguments: {self.args[1:]}")
        self.game = Popen(
            self.args,
            cwd=self.executable_purepath.parent,
            stdout=PIPE,
            stderr=STDOUT,
            universal_newlines=True,
            encoding="utf8",
        )

        while self.game.poll() is None:
            output = self.game.stdout.readline()
            if not output:
                break

            output = output.strip()
            if not output.startswith(tuple(self.hooks.keys())):
                continue

            for key, hooks in self.hooks.items():
                if output.startswith(key):
                    for hook in hooks:
                        hook(output[len(key):], lambda s: print("would send: " + key + s))

    def add_hook(self, pattern, target, source=None):
        """Add a target function to be called when pattern is detected

        Parameters
        ----------
        pattern : str
            pattern to look for in stdout
        target : function
            function to call when pattern is detected
        """
        if target in self.hooks[pattern]:
            return  # Function already hooked

        self.hooks[pattern].append(target)
        if source is not None:
            target = f"{target} from {source}"
        print(f"Adding hook on \"{pattern}\" with {target}")

    def load_plugins(self):
        for module_finder, name, _ in pkgutil.iter_modules(self.plugins_paths):
            spec = module_finder.find_spec(name)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            self.add_hook(module.prefix, module.hook, name)
