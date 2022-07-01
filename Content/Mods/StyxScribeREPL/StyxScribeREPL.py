import threading
import sys
import os
import contextlib
import signal
from io import StringIO
from traceback import format_exception_only
import builtins

_prefix = "StyxScribeREPL:"
_prefix_py = "Py:"

def End():
    Scribe.Close(True)

_globals = {a:b for a,b in builtins.__dict__.items() if not a.startswith('_')}
_locals = None

def RunLua(s):
    Scribe.Send("StyxScribeREPL: "+ s)

def _run_py_eval(s, g, l):
    try:
        return eval(compile(s, '<string>', 'single'), g, l)
    except SyntaxError as e:
        if e.args[0] == "unexpected EOF while parsing":
            return eval(compile(s, '<string>', 'exec'), g, l)
        else:
            raise SyntaxError from e

def _run_py(s):
    _stdout = StringIO()
    with contextlib.redirect_stdout(_stdout):
        RunPython(s)
    _stdout.flush()
    io = _stdout.getvalue()
    if '\n' in io:
        print("".join((f"\n{_prefix_py} "+s for s in io.split('\n')[:-1]))[1:])
    else:
        print(io,end='')

def RunPython(s):
    global _locals
    if _locals is None:
        _locals = {"end":End,"End":End,"END":End}
        _locals.update(dict(Scribe.modules))
        _locals["scribe"] = Scribe
        _locals["Scribe"] = Scribe
    s = s.lstrip()
    try:
        _run_py_eval(s, _globals, _locals)
    except Exception:
        print(exception_string(), end='')

def exception_string():
    return "".join(format_exception_only(*(sys.exc_info()[:2])))

class KeyboardThread(threading.Thread):
    #repurposed from https://stackoverflow.com/a/57387909
    def __init__(self, input_cbk = None, name='keyboard-input-thread'):
        self.input_cbk = input_cbk
        super(KeyboardThread, self).__init__(name=name)
        self.start()

    def run(self):
        try:
            while True:
                self.input_cbk(input()) #waits to get input + Return
        except EOFError:
            End()
        except KeyboardInterrupt:
            End()

def evaluate(inp):
    #evaluate the keyboard input
    if inp:
        if inp[:1] == ">":
            _run_py(inp[1:])
        else:
            RunLua(inp)

def Load():
    #start the Keyboard thread
    Scribe.AddOnRun(lambda: KeyboardThread(evaluate), __name__)
    Scribe.AddHook(_run_py, _prefix, __name__)
    Scribe.IgnorePrefixes.append(_prefix)
