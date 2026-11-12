rem Only Wine's own programs, for 15 s: its script host, from its Windows
rem folder, runs a script that waits. Beside it run the programs Wine and
rem Proton start by themselves.
echo WScript.Sleep(15000);> C:\wine-own-wait.js
C:\windows\system32\wscript.exe //B C:\wine-own-wait.js
echo ArkadeOS> C:\wine-own-ok.txt
