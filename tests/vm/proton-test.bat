echo ArkadeOS> C:\proton-ok.txt
rem A 32-bit program too, as the Battle.net installer is.
C:\windows\syswow64\cmd.exe /c echo ArkadeOS> C:\proton-32-ok.txt
rem Stay running for a while, as a game does (the power profile watcher polls every 3 s).
timeout /t 20 /nobreak > nul
