from hades_listener import HadesListener

with open("out.txt","w") as file:
    prefix = ""
    def read(x,_):
        x = x[len(prefix):]
        print(x)
        file.write(x+'\n')
    subsume = HadesListener()
    subsume.add_hook(prefix,read)
    subsume.load_plugins()
    subsume.launch(False)
