#Requires AutoHotkey v2.0
#SingleInstance Force
#I replaced the name of the game with "Game" but left other hints intact
SetBatchLines -1

; Hotkey to show mouse coordinates (hold Win+Alt+Shift)
#(!Shift):: 
    ToolTip("Mouse: " . Format("{}, {}", MouseGetPosX(), MouseGetPosY()))
    SetTimer(() => ToolTip(), 3000)  ; hide after 3 sec
return

; Main automation sequence
F1::  ; Press F1 to start
{
    ; 1. Launch Steam + Game (adjust path if needed)
    Run("steam://rungameid/1128810")
    WinWait("Game: Global Domination", , 30)
    if (ErrorLevel)
    {
        MsgBox("Game failed to launch")
        ExitApp()
    }
    WinActivate()
    WinMaximize()
    Sleep(15000)  ; wait for game to load - adjust as needed

    ; 2. Click sequence - REPLACE THESE COORDINATES WITH YOURS
    clicks := [
        [960, 540],  // Button 1 (example: center screen)
        [960, 600],  // Button 2
        [960, 660]   // Button 3
    ]

    for index, coord in clicks
    {
        MouseMove(coord[1], coord[2], 0)  ; 0 = instant move
        Click()
        Sleep(2000)  ; wait between clicks
    }

    ; 3. Close game
    ProcessClose("Game.exe")
    Sleep(2000)
    ; Optional: ProcessClose("steam.exe")  ; uncomment to close Steam too

    MsgBox("Sequence completed!")
}
return
