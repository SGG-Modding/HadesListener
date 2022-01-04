from hades_listener import HadesListener

with open("out.txt","w") as file:
    def read(x,_):
        print(x)
        file.write(x+'\n')
    subsume = HadesListener()
    subsume.add_hook(read, "", "subsume")
    subsume.load_plugins()
    subsume.launch(False)
