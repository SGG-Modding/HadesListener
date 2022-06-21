"""
Magic_Gonads (Discord: Magic_Gonads#7347)
Museus (Discord: Museus#7777)
"""
from collections import defaultdict, OrderedDict
import os
import sys
import platform
import pathlib
import pkgutil
import importlib.util
import contextlib
import signal
import asyncio
import functools
import inspect
from asyncio import create_subprocess_exec as Popen
from asyncio.subprocess import PIPE, STDOUT

# Do not include extension
EXECUTABLE_NAMES = { "hades" : "Hades", "pyre": "Pyre" }
# Do not include leading character (/ or -)
EXECUTABLE_ARGS = ["DebugDraw=true", "DebugKeysEnabled=true", "RequireFocusToUpdate=false"]
PLUGIN_SUBPATH = "StyxScribeScripts"
LUA_PROXY_STDIN = "proxy_stdin.txt"
LUA_PROXY_FALSE = "proxy_first.txt"
LUA_PROXY_TRUE = "proxy_second.txt"
PROXY_LOADED_PREFIX = "StyxScribe: ACK"
INTERNAL_IGNORE_PREFIXES = (PROXY_LOADED_PREFIX,)
OUTPUT_FILE = "game_output.log" 

#https://github.com/pallets/click/issues/2033#issue-960810534
def make_sync(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        return asyncio.run(func(*args, **kwargs))
    return wrapper

async def async_generator():
    yield
async_generator = type(async_generator())

def ispromise(promise):
    return asyncio.iscoroutine(promise) or isinstance(promise, async_generator)

class StyxScribe:
    """
    Used to launch the game with a wrapper that listens for specified patterns.
    Calls any functions that are added via `add_hook` when patterns are detected.
    """

    class Modules(OrderedDict):
        def __getattr__(self, key):
            if self.__dict__.__contains__(key):
                return self.__dict__.__getitem__(key)
            return self.__getitem__(key)
        def __hasattr__(self, key):
            if self.__dict__.__contains__(key):
                return True
            return self.__contains__(key)

    def __init__(self, game="Hades"):
        self.executable_name = EXECUTABLE_NAMES[game.lower()]
        if platform.system() != "Darwin":
            self.executable_purepath = (
                pathlib.PurePath() / "x64" / f"{self.executable_name}.exe"
            )
            self.args = [f"/{arg}" for arg in EXECUTABLE_ARGS]
            self.plugins_paths = [str(
                pathlib.PurePath() / "Content" / PLUGIN_SUBPATH
            )]
        else:
            self.executable_purepath = pathlib.PurePath() / self.executable_name
            self.args = [f"-{arg}" for arg in executable_args]
            self.plugins_paths = [str(
                pathlib.PurePath() / "Contents/Resources/Content" / PLUGIN_SUBPATH
            )]

        self.executable_cwd_purepath = self.executable_purepath.parent
        if self.executable_name == "Pyre":
            self.executable_cwd_purepath = self.executable_cwd_purepath.parent
            
        self.proxy_purepaths = {
            None: self.executable_cwd_purepath / LUA_PROXY_STDIN,
            False: self.executable_cwd_purepath / LUA_PROXY_FALSE,
            True: self.executable_cwd_purepath / LUA_PROXY_TRUE
        }
        
        self.args.insert(0, self.executable_purepath)
        self.hooks = defaultdict(list)
        self.modules = self.Modules()
        self.modules[__name__] = sys.modules[__name__]
        self.ignore_prefixes = list(INTERNAL_IGNORE_PREFIXES)
        
        self.queue = None
        self.loop = None

    def close(self, abort=True):
        try:
            self.game.terminate()
        except:
            pass
        with contextlib.suppress(FileNotFoundError):
            for path in self.proxy_purepaths.values():
                os.remove(path)
        if abort:
            os.kill(os.getpid(), signal.SIGTERM)

    def launch(self,echo=True,log=OUTPUT_FILE):
        """
        Launch the game and listen for patterns in self.hooks
        """
        if echo:
            print(f"Running {self.args[0]} with arguments: {self.args[1:]}")

        proxy_switch = False

        def sane(message):
            equals = '='*(1+message.count('='))
            return f"[{equals}[{message}]{equals}]"

        def quick_write_file(path, content):
            with open(path, 'w', encoding="utf8") as file:
                file.write(content)

        def setup_proxies():
            nonlocal proxy_switch
            prefix = f"print({sane(PROXY_LOADED_PREFIX)});"
            oldproxy = f"return {sane(self.proxy_purepaths[proxy_switch].name)}"
            newproxy = f"return {sane(self.proxy_purepaths[not proxy_switch].name)}"
            #point lua's entry to next proxy
            quick_write_file(self.proxy_purepaths[None], newproxy)
            #point old proxy to next proxy
            quick_write_file(self.proxy_purepaths[proxy_switch], newproxy)
            #point next proxy to old proxy
            proxy_switch = not proxy_switch
            quick_write_file(self.proxy_purepaths[proxy_switch], prefix+oldproxy)

        async def send_loop():
            #https://gist.github.com/tomschr/39734f0151a14187fd8f4844f66be6ba#file-asyncio-producer-consumer-task_done-py-L22
            while True:
                message = await self.queue.get()

                with open(self.proxy_purepaths[proxy_switch], 'a', encoding="utf8") as file:
                    if echo and not message.startswith(tuple(self.ignore_prefixes)):
                        print(f"In: {message}")
                    file.write(f",{sane(message)}")
                    file.flush()

                self.queue.task_done()

        async def send(message):
            await self.queue.put(message)
            await self.queue.join()

        self.send = lambda msg: asyncio.run_coroutine_threadsafe(send(msg),self.loop)

        @make_sync
        async def run(out=None):
            setup_proxies()

            self.game = await Popen(
                str(self.args[0]),*self.args[0:],
                cwd=self.executable_purepath.parent,
                stdout=PIPE,
                stderr=STDOUT
            )

            self.loop = asyncio.get_event_loop()
            self.queue = asyncio.Queue()
            sender = asyncio.ensure_future(send_loop())

            try:
                while self.game.returncode is None:
                    output = (await self.game.stdout.readline()).decode()
                    if not output:
                        break
                    output = output[:-1]
                    if not output.startswith(tuple(self.ignore_prefixes)):
                        if echo:
                            print(f"Out: {output}")
                        if out:
                            print(output, file=out)
                            out.flush()

                    if output.startswith(PROXY_LOADED_PREFIX):
                        setup_proxies()

                    for prefix, callbacks in self.hooks.items():
                        if output.startswith(prefix):
                            for callback in callbacks:
                                promise = callback(output[len(prefix):])
                                if ispromise(promise):
                                    await promise
            except KeyboardInterrupt:
                pass

            sender.cancel()
            self.queue = None
            self.loop = None
            self.close()

        if log:
            with open(log, 'w', encoding="utf8") as out:
                run(out)
        else:
            run()

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
        modules = OrderedDict()
        for module_finder, name, _ in pkgutil.iter_modules(self.plugins_paths):
            spec = module_finder.find_spec(name)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            module.scribe = self
            modules[name] =  module
        print("Found Modules: "+', '.join(modules.keys()))
        def key(t):
            module = t[1]
            if hasattr(module, "priority"):
                return module.priority
            return 100
        modules = OrderedDict(sorted(modules.items(), key=key))
        self.modules.update(modules)
        print("Loading Modules: "+', '.join(modules.keys()))
        for module in modules.values():
            if hasattr(module, "load"):
                module.load()
            elif hasattr(module, "callback"):
                self.add_hook(module.callback, getattr(module, "prefix", name + '\t'), name)
