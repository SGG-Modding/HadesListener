#repurposed from https://stackoverflow.com/questions/2408560/non-blocking-console-input/57387909#57387909

import threading

class KeyboardThread(threading.Thread):

    def __init__(self, input_cbk = None, name='keyboard-input-thread'):
        self.input_cbk = input_cbk
        super(KeyboardThread, self).__init__(name=name)
        self.start()

    def run(self):
        while True:
            self.input_cbk(input()) #waits to get input + Return

run = str

def my_callback(inp):
    #evaluate the keyboard input
    if inp:
        if inp[:2] == "% ":
            try:
                print(eval(inp[2:], globals(), locals()))
            except Exception as e:
                print(e.value)
        elif inp[:2] == "^ ":
            try:
                exec(inp[2:], globals(), locals())
            except Exception as e:
                print(e.value)
        else:
            if inp[:2] == "$ ":
                inp = "return " + inp[2:]
            run(inp)

#start the Keyboard thread
kthread = KeyboardThread(my_callback)

prefix = "HadesListenerREPL: "
def callback( msg, send ):
    global run
    run = send
