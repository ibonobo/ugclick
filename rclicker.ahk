#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All

; ================= CONFIGURE THIS =================
STEAM_EXE := "C:\\Program Files (x86)\\Steam\\steam.exe"
RISK_APPID := "1128810"

; Folder where button screenshots live
BUTTON_DIR := A_ScriptDir "\buttons\"

; Button images clicked in order (create these in buttons/)
BUTTON_SEQUENCE := [
    "start_full.png",
    "claim.png",
;    "confirm.png"
]

; Timeouts (seconds)
WAIT_STEAM_SEC := 60      ; wait for Steam process to be ready
WAIT_RISK_SEC  := 180     ; Risk update phase can take minutes
WAIT_BUTTON_SEC:= 60      ; wait for each main-menu button to appear
OK_HUNT_SEC    := 10      ; how long to hunt for optional OK button
CLICK_DELAY_MS := 3000    ; pause between clicks
; =================================================

; Wait until a process exists (polls every second)
WaitForProcess(processName, seconds) {
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        if ProcessExist(processName)
            return ProcessExist(processName)  ; returns PID
        Sleep(1000)
    }
    return 0
}

; Wait until a window belonging to a process exists (polls every second)
WaitForWindow(processName, seconds) {
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        if WinExist("ahk_exe " . processName)
            return WinGetID("ahk_exe " . processName)
        Sleep(1000)
    }
    return 0
}

; Wait until an image is found on screen; click it when found
ClickImage(imagePath, seconds) {
    deadline := A_TickCount + seconds * 1000
    while (A_TickCount < deadline) {
        TryClickOk()
        if FindAndClick(imagePath) {
            Sleep(1500)
            ; if the button is gone, the click worked; otherwise loop and click again
            if !ImageSearch(&vx, &vy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*20 " . imagePath)
                return true
        }
        Sleep(2000)
    }
    return false
}

; ================= start Claude fix 261108 =================
; Size of an image file in pixels
GetImageSize(path, &w, &h) {
    g := Gui("-DPIScale")
    pic := g.Add("Picture", , path)
    pic.GetPos(, , &w, &h)
    g.Destroy()
}

; Hover first, then press and release with pauses (Unity ignores instant clicks)
ClickAt(x, y) {
    MouseMove(x - 5, y - 5)
    Sleep(150)
    MouseMove(x, y)
    Sleep(300)
    Click("Down")
    Sleep(120)
    Click("Up")
}

; Find an image and click its center; returns true if found and clicked
FindAndClick(imagePath) {
    if ImageSearch(&fx, &fy, 0, 0, A_ScreenWidth, A_ScreenHeight, "*20 " . imagePath) {
        GetImageSize(imagePath, &w, &h)
        ClickAt(fx + w // 2, fy + h // 2)
        return true
    }
    return false
}

; Click the optional OK button if it is on screen
TryClickOk() {
    okFile := BUTTON_DIR . "ok_button.png"
    if FileExist(okFile) && FindAndClick(okFile) {
        Sleep(1000)
        return true
    }
    return false
}
; ================= endClaude fix 261108 =================

Main() {
    ; --- 1. Launch Steam silently (suppresses store/deals popups) ---
    ; Steam -silent runs without a window (tray only), so wait for PROCESS
    if !ProcessExist("Steam.exe") {
        Run(STEAM_EXE . " -silent")
        ; Give Steam time to initialize
        Sleep(3000)
    }
    steamPid := WaitForProcess("Steam.exe", WAIT_STEAM_SEC)
    if (!steamPid) {
        MsgBox("Steam process failed to start within " . WAIT_STEAM_SEC . " seconds")
        ExitApp()
    }

    ; --- 2. Launch Risk via steam:// protocol (works without Steam window) ---
    Run("steam://rungameid/" . RISK_APPID)

    ; --- 3. Wait for Risk window to appear (covers long update phase) ---
    riskId := WaitForWindow("RISK.exe", WAIT_RISK_SEC)
    if (!riskId) {
        MsgBox("Risk never appeared - update may have failed")
        ExitApp()
    }

    WinActivate(riskId)
    WinMaximize(riskId)
    Sleep(2000)   ; brief settle after maximize

    ; --- 4. Optional OK button: click only if it pops up ---
    deadline := A_TickCount + OK_HUNT_SEC * 1000
    while (A_TickCount < deadline) {
        if TryClickOk()
            break
        Sleep(1000)
    }
    ; --- 5. Main button sequence (image-based clicking) ---
    for index, btnFile in BUTTON_SEQUENCE {
        imgPath := BUTTON_DIR . btnFile
        if !FileExist(imgPath) {
            MsgBox("Missing button image: " . imgPath)
            ExitApp()
        }
        if !ClickImage(imgPath, WAIT_BUTTON_SEC) {
            MsgBox("Button not found on screen: " . btnFile)
            ExitApp()
        }
        Sleep(CLICK_DELAY_MS)
    }

    ; --- 6. Close everything ---
    ProcessClose("RISK.exe")
    Sleep(2000)
    ProcessClose("Steam.exe")

    MsgBox("Daily sequence complete!")
}

Main()   ; runs when script starts
