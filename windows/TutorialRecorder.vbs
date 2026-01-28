Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\danie\Desktop\Projects\Personal Projects\obs-tutorial-recorder\windows"
WshShell.Run """C:\Users\danie\AppData\Local\Programs\Python\Python311\pythonw.exe"" ""C:\Users\danie\Desktop\Projects\Personal Projects\obs-tutorial-recorder\windows\run.py""", 0, False
