echo ArkadeOS> C:\proton-ok.txt
rem A 32-bit program too, as the Battle.net installer is.
C:\windows\syswow64\cmd.exe /c echo ArkadeOS> C:\proton-32-ok.txt
rem A game runs from a folder of its own, never from Wine's Windows folder, and
rem stays for a while (the power profile watcher looks every 3 s). A copy of
rem Wine's script host stands in for one, with a script that waits 20 s. Wine's
rem timeout would not: with no keyboard it ends at once.
mkdir C:\Games\ArkadeTest 2> nul
echo WScript.Sleep(20000);> C:\Games\ArkadeTest\wait.js
copy /y C:\windows\system32\wscript.exe C:\Games\ArkadeTest\ArkadeTest.exe > nul
C:\Games\ArkadeTest\ArkadeTest.exe //B C:\Games\ArkadeTest\wait.js
