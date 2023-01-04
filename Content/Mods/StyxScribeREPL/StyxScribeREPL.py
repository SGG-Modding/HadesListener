import threading
import sys
import os
import contextlib
import signal
from io import StringIO
from traceback import format_exception_only
import builtins

_prefix_py = "Py:\t"

def End():
    Scribe.Close(True)

_globals = {a:b for a,b in builtins.__dict__.items() if not a.startswith('_')}
_locals = None

def RunLua(s):
    Scribe.Send("StyxScribeREPL: "+ s)

def _run_py_eval(s, g, l):
    try:
        return eval(s, g, l)
    except SyntaxError:
        try:
            return eval(compile(s, '<string>', 'single'), g, l)
        except SyntaxError as e:
            if e.args[0] == "unexpected EOF while parsing":
                return eval(compile(s, '<string>', 'exec'), g, l)
            else:
                raise SyntaxError from e

def RunPython(s, echo=None):
    _stdout = StringIO()
    rets = None
    with contextlib.redirect_stdout(_stdout):
        rets = _run_py(s)
    _stdout.flush()
    io = _stdout.getvalue()
    if echo and rets is not None:
            io = str(rets) + '\n'
    if '\n' in io:
        print("".join((f"\n{_prefix_py}"+s for s in io.split('\n')[:-1]))[1:])
    else:
        print(io,end='')
    return rets

def _run_py(s):
    global _locals
    if _locals is None:
        _locals = {"end":End,"End":End,"END":End}
        _locals.update(dict(Scribe.modules))
        _locals["scribe"] = Scribe
        _locals["Scribe"] = Scribe
    s = s.lstrip()
    try:
        return _run_py_eval(s, _globals, _locals)
    except Exception:
        print(exception_string(), end='')

def exception_string():
    return "".join(format_exception_only(*(sys.exc_info()[:2])))

class KeyboardThread(threading.Thread):
    #repurposed from https://stackoverflow.com/a/57387909
    def __init__(self, input_cbk = None, name='keyboard-input-thread'):
        self.input_cbk = input_cbk
        super(__class__, self).__init__(name=name)
        self.start()

    def run(self):
        try:
            while True:
                self.input_cbk(input()) #waits to get input + Return
        except EOFError:
            End()
        except KeyboardInterrupt:
            End()

def _runPython(message):
    return RunPython(message, True)

def evaluate(inp):
    #evaluate the keyboard input
    if inp:
        if inp[:1] == ">":
            _runPython(inp[1:])
        else:
            RunLua(inp)

Priority = 0

def Load():
    #start the Keyboard thread
    Scribe.AddOnRun(lambda: KeyboardThread(evaluate), __name__)
    Scribe.AddHook(_runPython, "StyxScribeREPL: ", __name__)
    Scribe.IgnorePrefixes.append("StyxScribeREPL: ")
