# ugclick
ways to play back a macro (mouse clicks) in a Unity game
this is vibecoded and I'm showing the convo in here (Windows Hermes with free model)

Having previously tried Anthropic's models, I thought this was going to be just as easy with free models; alas, it was not.

## Intro with AI

the "click buttons in the game" part is the tricky bit. Here's the breakdown:

Step
Difficulty
Approach
Launch Steam	Easy	steam.exe or steam:// protocol
Launch game	Easy	steam://rungameid/<appid>
Click in-game buttons	Hard	Image recognition or fixed coordinates
Close everything	Easy	taskkill or steam://exit
Daily schedule	Easy	Windows Task Scheduler
The challenge: Games don't expose standard Windows UI controls, so normal automation tools (like pywinauto) can't "see" buttons inside a game. You'd need one of:

Image recognition — AutoHotkey with FindText, or Python with pyautogui + opencv to find and click button screenshots. Works but breaks if resolution/theme changes.
Fixed coordinates — pyautogui.click(x, y) at hardcoded positions. Simple but fragile.
Memory editing — Read/write game memory to trigger actions directly. Game-specific and complex.
Rough AutoHotkey sketch:

; Launch Steam + game (1128810)
Run, steam://rungameid/1234560  ; replace with Game's appid
WinWait, Game
Sleep, 10000  ; wait for load

; Click buttons via image search
ImageSearch, FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, button.png
if (ErrorLevel = 0)
    Click, %FoundX%, %FoundY%

; Close
Process, Close, Game.exe
Process, Close, steam.exe
Then schedule it daily via Task Scheduler (schtasks or GUI).

The Steam app is **GAME: Global Domination** (appid `1128810`).

Launch command:
```bat
steam://rungameid/1128810
```

Now the hard part — clicking buttons **inside the game**. Since it's a Unity-based game, standard Windows automation won't see internal buttons. You have three real options:

| Method | Reliability | Effort |
|--------|-------------|--------|
| **AutoHotkey + ImageSearch** | Medium — breaks on resolution/UI changes | Low |
| **Python + OpenCV template matching** | Medium — same fragility | Medium |
| **Unity input injection (Il2CppDumper + memory)** | High — works regardless of screen | High |

**Quick AutoHotkey proof-of-concept** (replace `button.png` with actual button screenshots):
```ahk
#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

; 1. Launch Steam + GAME
Run, steam://rungameid/1128810
WinWait, GAME: Global Domination,, 60
if ErrorLevel {
    MsgBox, Game failed to launch
    ExitApp
}
WinActivate
WinMaximize
Sleep, 15000  ; adjust for load time

; 2. Click sequence — capture each button as button1.png, button2.png...
Loop, 3 {
    btn := "button" A_Index ".png"
    ImageSearch, x, y, 0, 0, A_ScreenWidth, A_ScreenHeight, %btn%
    if ErrorLevel = 0 {
        Click, %x%, %y%
        Sleep, 2000
    } else {
        MsgBox, Could not find %btn%
        break
    }
}

; 3. Close
Process, Close, GAME.exe
Sleep, 2000
Process, Close, steam.exe
```

**Daily schedule:** Save as `GAME_daily.ahk`, then in Task Scheduler:
- Trigger: Daily at your chosen time
- Action: `AutoHotkey.exe` → `C:\path\GAME_daily.ahk`
- "Run whether user is logged on or not" + "Run with highest privileges"

**Caveats:**
- Screenshots must match *exact* resolution + UI scale
- Game updates can move/change buttons
- Steam may show "Preparing to launch..." dialog first

## Unity Input Injection Approach for IL2CPP Games

### Toolchain
| Tool | Purpose |
|------|---------|
| **MelonLoader** | Best IL2CPP mod loader, easy install |
| **IL2CppDumper** | Dump `GameAssembly.dll` + `global-metadata.dat` → C# assemblies |
| **Harmony** | Hook methods at runtime |
| **dnSpy/ILSpy** | Browse dumped assemblies |

---

### Step 1: Install MelonLoader
```bash
# Download MelonLoader.Installer.exe from https://github.com/LavaGang/MelonLoader/releases
# Run it, select GAME.exe (in Steam/steamapps/common/GAME Global Domination/)
# Launch game once → creates Mods/ folder
```

---

### Step 2: Dump Assemblies (find input code)
```bash
# Get IL2CppDumper from https://github.com/Perfare/Il2CppDumper
# Run: Il2CppDumper.exe GameAssembly.dll GAME_Global_Domination_Data/il2cpp_data/Metadata/global-metadata.dat
# Output: DummyDll/ folder with C# assemblies
```

Search dumped code for:
- `UnityEngine.Input` usage
- Custom input managers (search `InputManager`, `Button`, `OnClick`, `PointerEventData`)
- UI system: `UnityEngine.UI.Button`, `EventSystem`, `StandaloneInputModule`

---

### Step 3: Write a MelonLoader Mod (C#)

**Project structure:**
```
GAMEAutoClicker/
├── GAMEAutoClicker.csproj
├── GAMEAutoClicker.cs
└── Properties/AssemblyInfo.cs
```

**GAMEAutoClicker.csproj:**
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.1</TargetFramework>
    <LangVersion>latest</LangVersion>
    <AssemblyName>GAMEAutoClicker</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="MelonLoader.Core" Version="0.6.6" />
    <PackageReference Include="HarmonyX" Version="2.11.0" />
    <Reference Include="UnityEngine.CoreModule">
      <HintPath>GAME_Global_Domination_Data/Managed/UnityEngine.CoreModule.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="UnityEngine.UI">
      <HintPath>GAME_Global_Domination_Data/Managed/UnityEngine.UI.dll</HintPath>
      <Private>false</Private>
    </Reference>
    <Reference Include="Assembly-CSharp">
      <HintPath>DummyDll/Assembly-CSharp.dll</HintPath>
      <Private>false</Private>
    </Reference>
  </ItemGroup>
</Project>
```

**GAMEAutoClicker.cs:**
```csharp
using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using MelonLoader;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

[assembly: MelonInfo(typeof(GAMEAutoClicker.GAMEAutoClicker), "GAMEAutoClicker", "1.0.0", "You")]
[assembly: MelonGame("SMG Studio", "GAME: Global Domination")]

namespace GAMEAutoClicker
{
    public class GAMEAutoClicker : MelonMod
    {
        private bool _sequenceStarted = false;
        private int _step = 0;
        private readonly string[] _buttonNames = { "PlayButton", "ContinueButton", "ConfirmButton" }; // <-- REPLACE with actual names

        public override void OnInitializeMelon()
        {
            LoggerInstance.Msg("GAMEAutoClicker loaded");
            
            // Hook into SceneManager to detect menu loads
            var sceneManager = typeof(UnityEngine.SceneManagement.SceneManager);
            var loadScene = sceneManager.GetMethod("LoadScene", new[] { typeof(string) });
            HarmonyInstance.Patch(loadScene, postfix: new HarmonyMethod(typeof(GAMEAutoClicker), nameof(OnSceneLoaded)));
        }

        public override void OnUpdate()
        {
            if (!_sequenceStarted) return;
            
            if (_step < _buttonNames.Length)
            {
                ClickButtonByName(_buttonNames[_step]);
                _step++;
            }
            else
            {
                _sequenceStarted = false;
                _step = 0;
                MelonLogger.Msg("Sequence complete, closing...");
                Application.Quit();
            }
        }

        private static void OnSceneLoaded(string sceneName)
        {
            MelonLogger.Msg($"Scene loaded: {sceneName}");
            if (sceneName.Contains("MainMenu") || sceneName.Contains("Lobby")) // adjust
            {
                Instance._sequenceStarted = true;
                Instance._step = 0;
            }
        }

        private void ClickButtonByName(string name)
        {
            var btn = GameObject.Find(name)?.GetComponent<Button>();
            if (btn == null)
            {
                // Fallback: search all buttons by text
                btn = Resources.FindObjectsOfTypeAll<Button>()
                    .FirstOrDefault(b => b.GetComponentInChildren<Text>()?.text.Contains(name, StringComparison.OrdinalIgnoreCase) == true);
            }
            
            if (btn != null)
            {
                ExecuteEvents.Execute(btn.gameObject, new PointerEventData(EventSystem.current), ExecuteEvents.pointerClickHandler);
                MelonLogger.Msg($"Clicked: {name}");
            }
            else
            {
                MelonLogger.Warning($"Button not found: {name}");
            }
        }
    }
}
```

---

### Step 4: Find Actual Button Names
1. Launch game with MelonLoader + **UnityExplorer** (put `UnityExplorer.BepInEx.dll` + `UniverseLib.dll` in `Mods/`)
2. Press **F2** in-game → browse scene hierarchy
3. Find button GameObjects → note their **exact names** or **text labels**
4. Update `_buttonNames` array

---

### Step 5: Build & Deploy
```bash
dotnet build GAMEAutoClicker.csproj -c Release
# Copy bin/Release/netstandard2.1/GAMEAutoClicker.dll to Mods/
```

---

### Step 6: Daily Automation (Windows)
**launch_GAME.bat:**
```bat
@echo off
cd /d "C:\Program Files (x86)\Steam\steamapps\common\GAME Global Domination"
start "" "GAME.exe"
```

**Task Scheduler:**
- Trigger: Daily
- Action: `C:\path\launch_GAME.bat`
- The mod auto-clicks and calls `Application.Quit()` → game closes → Steam stays running

**To close Steam too:** Add a second task 5min later:
```bat
taskkill /im steam.exe /f
```

---

### Key Challenges You'll Hit
| Issue | Fix |
|-------|-----|
| Button names change per scene | Hook `SceneManager.sceneLoaded` + search each scene |
| Animations delay clickability | Add `WaitForEndOfFrame` coroutine before click |
| IL2CPP obfuscation | Use dumped `Assembly-CSharp.dll` to find real types |
| Anti-cheat | GAME doesn't have kernel AC, but verify EULA |

---

Want me to:
1. **Dump the assemblies for you** (if you upload `GameAssembly.dll` + `global-metadata.dat`)?
2. **Write the full mod project** once you get button names from UnityExplorer?
3. **Set up the MelonLoader install** on your machine?

After all this, I tried installing Melonloader which then took over the Game install and after that, I could no longer play the game without this thing getting in the way. So I re-installed the game and tried the AutoHotKey route.

Here's how to create and record an AutoHotkey macro for clicking buttons in GAME: Global Domination:

## 1. Install AutoHotkey (if not done)
Download from: https://www.autohotkey.com/
- Choose "Express Installation" (v2.0)
- Install to default location

## 2. Two approaches for clicking buttons

### Approach A: Fixed Coordinates (Simplest)
Best if your game resolution/UI scale never changes.

**Steps:**
1. Launch GAME normally and get to the screen with your first button
2. Press `Win + Alt + Shift` to pause the script (we'll add this hotkey)
3. Move mouse over the button, note the coordinates shown in the tray tip
4. Repeat for each button in sequence

**Template script (`GAME_clicker.ahk`):**
```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
SetBatchLines -1

; Hotkey to show mouse coordinates (hold Win+Alt+Shift)
#(!Shift):: 
    ToolTip("Mouse: " . Format("{}, {}", MouseGetPosX(), MouseGetPosY()))
    SetTimer(() => ToolTip(), 3000)  ; hide after 3 sec
return

; Main automation sequence
F1::  ; Press F1 to start
{
    ; 1. Launch Steam + GAME (adjust path if needed)
    Run("steam://rungameid/1128810")
    WinWait("GAME: Global Domination", , 30)
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
    ProcessClose("GAME.exe")
    Sleep(2000)
    ; Optional: ProcessClose("steam.exe")  ; uncomment to close Steam too

    MsgBox("Sequence completed!")
}
return
```

**To get your coordinates:**
1. Run the script above
2. Hold `Win + Alt + Shift` - a tooltip shows current mouse position
3. Hover over each button in the game and note the (x, y) values
4. Replace the example coordinates in the `clicks` array

### Approach B: Image Search (More Robust)
Works across minor UI/theme changes if you have button screenshots.

**Steps:**
1. Launch the game and navigate to each screen
2. Press `PrintScreen` to capture the screen
3. Paste into Paint, crop just the button, save as PNG (e.g., `start_button.png`)
4. Repeat for each button

**Template script using ImageSearch:**
```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
SetBatchLines -1

; Folder where button images are stored
buttonDir := A_ScriptDir "\buttons\"

F1::  ; Press F1 to start
{
    Run("steam://rungameid/1128810")
    WinWait("GAME: Global Domination", , 30)
    if (ErrorLevel)
    {
        MsgBox("Game failed to launch")
        ExitApp()
    }
    WinActivate()
    WinMaximize()
    Sleep(15000)

    ; List of button image filenames in click order
    buttons := ["start.png", "continue.png", "confirm.png"]  ; <-- REPLACE WITH YOUR FILES

    for index, btn in buttons
    {
        imgPath := buttonDir . btn
        if !FileExist(imgPath)
        {
            MsgBox("Image not found: " . imgPath)
            Break
        }

        ; Search entire screen for the image
        ImageSearch FoundX, FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, imgPath
        if (ErrorLevel = 0)  ; found
        {
            Click(FoundX, FoundY)
            Sleep(2000)
        }
        else  ; not found
        {
            MsgBox("Could not find: " . btn)
            Break
        }
    }

    ProcessClose("GAME.exe")
    MsgBox("Sequence completed!")
}
return
```

## 3. Make it run daily (Task Scheduler)
1. Save your script as `GAME_daily.ahk`
2. Open Task Scheduler (`taskschd.msc`)
3. Create Basic Task:
   - Trigger: Daily at your chosen time
   - Action: Start a program
   - Program: `C:\Program Files\AutoHotkey\AutoHotkey.exe`
   - Arguments: `"C:\path\to\GAME_daily.ahk"`
4. Check "Run with highest privileges" if needed
5. Finish

## 4. Important Notes
- **Resolution matters**: Fixed coordinates only work at the exact same resolution/UI scale
- **Game updates**: Button positions/images may change after patches
- **Anti-cheat**: GAME doesn't have kernel-level AC, but avoid detectable automation if concerned
- **Testing**: Start with just launching the game (`F1` hotkey) before adding clicks

## Quick Test
1. Install AHK
2. Create a test script with just:
   ```ahk
   F1:: MsgBox("AHK works!")
   ```
3. Press F1 - you should see the message
4. Then build up to the full sequence

Which approach would you prefer to try first? I can help you generate the exact script once you have coordinates or button images.
