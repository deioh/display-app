;==================================================================================
; launcher.au3 — Queue Display Kiosk Controller (AutoIt)
;==================================================================================
; Manages Chrome kiosk windows for hospital queue display.
; Supports multiple display modes configured via config.ini.
;
; Modes:
;   dual_url    — Two URLs side by side in Chrome
;   single_url  — One URL full width
;   video_left  — Local video (left) + URL (right)
;   video_right — URL (left) + local video (right)
;
; Hotkeys:
;   F5         — Restart all browser windows
;   F6         — Cycle through display modes
;   F8         — Exit kiosk app
;   F9         — Toggle video mute/play
;
; Commander: Deioh
; Created: 2026-09-23
;==================================================================================

#include <Misc.au8>
#include <WinAPIEx.au8>
#include <File.au3>

;----------------------------------------------------------------------------------
; Configuration
;----------------------------------------------------------------------------------
Global $g_sConfig = @ScriptDir & "\config.ini"
Global $g_sChromeExe = ""
Global $g_aURLs[2] = ["", ""]
Global $g_sVideoFile = ""
Global $g_sDisplayMode = "dual_url"
Global $g_iRefreshSecs = 5
Global $g_bMuted = True ; Start muted to avoid autoplay blocking

; Track running processes so we can restart them
Global $g_aBrowsers[4] = [0, 0, 0, 0] ; PID slots for up to 4 windows
Global $g_iCurrentMode = 0
Global $g_bRunning = True

;----------------------------------------------------------------------------------
; Parse configuration from INI file
;----------------------------------------------------------------------------------
Func _LoadConfig()
    ; Locate Chrome executable
    $g_sChromeExe = IniRead($g_sConfig, "Settings", "ChromeExe", "")
    If $g_sChromeExe = "" Or Not FileExists($g_sChromeExe) Then
        ; Try common locations
        Local $aPaths[] = [ @ProgramFilesDir & "\Google\Chrome\Application\chrome.exe", _
                            @ProgramFilesDir & "(x86)\Google\Chrome\Application\chrome.exe", _
                            EnvGet("LOCALAPPDATA") & "\Google\Chrome\Application\chrome.exe", _
                            @WindowsDir & "\System32\chrome.exe" ]
        For $sPath In $aPaths
            If FileExists($sPath) Then
                $g_sChromeExe = $sPath
                ExitLoop
            EndIf
        Next
    EndIf

    ; Load URLs
    $g_aURLs[0] = IniRead($g_sConfig, "URLs", "URL1", "https://example.com")
    $g_aURLs[1] = IniRead($g_sConfig, "URLs", "URL2", "https://example.com")

    ; Load video file path
    $g_sVideoFile = IniRead($g_sConfig, "Settings", "VideoFile", @ScriptDir & "\video.mp4")

    ; Load display mode
    $g_sDisplayMode = IniRead($g_sConfig, "Settings", "DefaultMode", "dual_url")
    Switch $g_sDisplayMode
        Case "dual_url", "single_url", "video_left", "video_right"
            ; Valid mode
        Case Else
            $g_sDisplayMode = "dual_url"
    EndSwitch

    ; Load refresh interval
    $g_iRefreshSecs = Number(IniRead($g_sConfig, "Settings", "RefreshSecs", "5"))

    ; Map mode name to index for cycling
    Local $aModes[] = ["dual_url", "single_url", "video_left", "video_right"]
    For $i = 0 To UBound($aModes) - 1
        If $g_sDisplayMode = $aModes[$i] Then
            $g_iCurrentMode = $i
            ExitLoop
        EndIf
    Next
EndFunc

;----------------------------------------------------------------------------------
; Calculate window positions based on display mode and screen size
;----------------------------------------------------------------------------------
Func _CalculateWindowPositions($sMode, ByRef $aPositions)
    Local $iScreenW = @DesktopWidth
    Local $iScreenH = @DesktopHeight
    Local $iGap = 5 ; Small gap between panes

    ReDim $aPositions[4][4] ; [x, y, width, height] for each pane slot

    Switch $sMode
        Case "dual_url"
            ; Left pane: 50% width
            $aPositions[0][0] = 0                    ; x
            $aPositions[0][1] = 0                    ; y
            $aPositions[0][2] = $iScreenW / 2 - $iGap ; width
            $aPositions[0][3] = $iScreenH             ; height

            ; Right pane: 50% width
            $aPositions[1][0] = $iScreenW / 2 + $iGap
            $aPositions[1][1] = 0
            $aPositions[1][2] = $iScreenW / 2 - $iGap
            $aPositions[1][3] = $iScreenH

        Case "single_url"
            ; Full screen
            $aPositions[0][0] = 0
            $aPositions[0][1] = 0
            $aPositions[0][2] = $iScreenW
            $aPositions[0][3] = $iScreenH

        Case "video_left"
            ; Left: video (40%), Right: URL (60%)
            $aPositions[0][0] = 0
            $aPositions[0][1] = 0
            $aPositions[0][2] = $iScreenW * 0.4 - $iGap
            $aPositions[0][3] = $iScreenH

            $aPositions[1][0] = $iScreenW * 0.4 + $iGap
            $aPositions[1][1] = 0
            $aPositions[1][2] = $iScreenW * 0.6 - $iGap
            $aPositions[1][3] = $iScreenH

        Case "video_right"
            ; Left: URL (60%), Right: video (40%)
            $aPositions[0][0] = 0
            $aPositions[0][1] = 0
            $aPositions[0][2] = $iScreenW * 0.6 - $iGap
            $aPositions[0][3] = $iScreenH

            $aPositions[1][0] = $iScreenW * 0.6 + $iGap
            $aPositions[1][1] = 0
            $aPositions[1][2] = $iScreenW * 0.4 - $iGap
            $aPositions[1][3] = $iScreenH
    EndSwitch

    Return 2 ; Number of active panes
EndFunc

;----------------------------------------------------------------------------------
; Launch browser windows based on mode
;----------------------------------------------------------------------------------
Func _LaunchBrowsers($iModeIndex)
    Local $aModes[] = ["dual_url", "single_url", "video_left", "video_right"]
    Local $sMode = $aModes[$iModeIndex]
    Local $aPositions[4][4]

    _CalculateWindowPositions($sMode, $aPositions)

    ; Kill existing browser processes first
    _KillBrowsers()

    ; Determine how many panes we need
    Local $iNumPanes = 2
    If $sMode = "single_url" Then $iNumPanes = 1

    For $i = 0 To $iNumPanes - 1
        Local $sURL = $g_aURLs[$i]
        Local $iX = $aPositions[$i][0]
        Local $iY = $aPositions[$i][1]
        Local $iW = $aPositions[$i][2]
        Local $iH = $aPositions[$i][3]

        If $sMode = "video_left" And $i = 0 Then
            ; Launch video in first pane using a local HTML wrapper
            _LaunchVideoPlayer($iX, $iY, $iW, $iH)
        ElseIf $sMode = "video_right" And $i = 1 Then
            ; Launch video in second pane
            _LaunchVideoPlayer($iX, $iY, $iW, $iH)
        Else
            _LaunchChrome($sURL, $iX, $iY, $iW, $iH)
        EndIf
    Next
EndFunc

Func _LaunchChrome($sURL, $iX, $iY, $iW, $iH)
    Local $sArgs = '--app="' & $sURL & '" --window-position=' & $iX & ',' & $iY
    Local $iPID = Run('"' & $g_sChromeExe & '" ' & $sArgs, "", @SW_MAXIMIZE)

    ; Wait for window to appear and position it
    ; Use class name "Chrome_WidgetWin_1" or match title containing URL
    Local $hWnd
    Local $iTimer = TimerInit()
    Do
        $hWnd = _WinAPI_EnumWindows()
        ; Simplified: poll for any new Chrome window
        Sleep(100)
    Until TimerDiff($iTimer) > 5000 Or $hWnd <> 0

    ; Fallback: try by process ID
    If $hWnd = 0 Then
        ; Just try to move any existing Chrome window
        ; This is a simplification — in production we'd track PIDs more carefully
    EndIf

    ; Store PID
    For $j = 0 To UBound($g_aBrowsers) - 1
        If $g_aBrowsers[$j] = 0 Then
            $g_aBrowsers[$j] = $iPID
            ExitLoop
        EndIf
    Next
EndFunc

Func _LaunchVideoPlayer($iX, $iY, $iW, $iH)
    ; Create a temporary HTML file that plays the video fullscreen
    Local $sTempHTML = @TempDir & "\kiosk_video_player.html"
    Local $sVideoPath = StringReplace($g_sVideoFile, "\", "\\")
    Local $sHTML = '<!DOCTYPE html><html><head><style>html,body{margin:0;padding:0;height:100%;overflow:hidden;background:#000}</style></head>' & _
                   '<body><video src="file:///' & $sVideoPath & '" autoplay muted loop playsinline style="width:100%;height:100%;object-fit:contain"></video></body></html>'

    Local $hFile = FileOpen($sTempHTML, 2)
    FileWrite($hFile, $sHTML)
    FileClose($hFile)

    ; Open in Chrome in app mode
    Local $sArgs = '--app="file://' & $sTempHTML & '" --window-position=' & $iX & ',' & $iY
    Local $iPID = Run('"' & $g_sChromeExe & '" ' & $sArgs, "", @SW_MAXIMIZE)

    For $j = 0 To UBound($g_aBrowsers) - 1
        If $g_aBrowsers[$j] = 0 Then
            $g_aBrowsers[$j] = $iPID
            ExitLoop
        EndIf
    Next
EndFunc

;----------------------------------------------------------------------------------
; Kill all browser processes managed by this script
;----------------------------------------------------------------------------------
Func _KillBrowsers()
    ; Kill tracked PIDs
    For $i = 0 To UBound($g_aBrowsers) - 1
        If $g_aBrowsers[$i] <> 0 Then
            ProcessClose($g_aBrowsers[$i])
            $g_aBrowsers[$i] = 0
        EndIf
    Next

    ; Aggressive fallback: kill any Chrome processes we launched
    ; (Use at own risk in production — could affect user sessions)
    ; ProcessClose("chrome.exe")

    Sleep(200) ; Brief pause so windows fully close
EndFunc

;----------------------------------------------------------------------------------
; Cycle display modes
;----------------------------------------------------------------------------------
Func _CycleMode()
    Local $aModes[] = ["dual_url", "single_url", "video_left", "video_right"]
    $g_iCurrentMode = Mod($g_iCurrentMode + 1, UBound($aModes))
    $g_sDisplayMode = $aModes[$g_iCurrentMode]

    MsgBox(64, "Display Mode", "Switched to: " & $g_sDisplayMode, 2, "")

    ; Restart with new mode
    _LaunchBrowsers($g_iCurrentMode)
EndFunc

;----------------------------------------------------------------------------------
; Restart all browser windows
;----------------------------------------------------------------------------------
Func _RestartBrowsers()
    _KillBrowsers()
    Sleep(500)
    _LaunchBrowsers($g_iCurrentMode)
EndFunc

;----------------------------------------------------------------------------------
; Monitoring loop — check browser health
;----------------------------------------------------------------------------------
Func _MonitorLoop()
    While $g_bRunning
        ; Check if our browser processes are still alive
        Local $bAllAlive = True
        For $i = 0 To UBound($g_aBrowsers) - 1
            If $g_aBrowsers[$i] <> 0 Then
                If Not ProcessExists($g_aBrowsers[$i]) Then
                    $bAllAlive = False
                    $g_aBrowsers[$i] = 0
                EndIf
            EndIf
        Next

        If Not $bAllAlive Then
            ; Restart crashed browsers
            Log("Browser process died — restarting displays...")
            _LaunchBrowsers($g_iCurrentMode)
        EndIf

        ; Simple heartbeat
        Sleep($g_iRefreshSecs * 1000)
    WEnd
EndFunc

;----------------------------------------------------------------------------------
; Utility: Log to console
;----------------------------------------------------------------------------------
Func Log($sMsg)
    ConsoleWrite("[" & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $sMsg & @CRLF)
EndFunc

;----------------------------------------------------------------------------------
; Main entry point
;----------------------------------------------------------------------------------
Func Main()
    ; Load configuration
    If Not FileExists($g_sConfig) Then
        MsgBox(16, "Error", "config.ini not found at " & $g_sConfig)
        Exit 1
    EndIf

    _LoadConfig()
    Log("Loaded configuration:")
    Log("  Chrome: " & $g_sChromeExe)
    Log("  Mode: " & $g_sDisplayMode)
    Log("  URL1: " & $g_aURLs[0])
    Log("  URL2: " & $g_aURLs[1])
    Log("  Video: " & $g_sVideoFile)

    ; Hide mouse cursor after 1s of inactivity (kiosk mode)
    ; _MouseTrap — would require additional lib

    ; Register hotkeys
    HotKeySet("{F5}", "_RestartBrowsers")  ; Restart all
    HotKeySet("{F6}", "_CycleMode")         ; Cycle display modes
    HotKeySet("{F8}", "_ExitKiosk")          ; Exit kiosk
    HotKeySet("{F9}", "_ToggleMute")        ; Mute/unmute

    ; Launch initial display mode
    _LaunchBrowsers($g_iCurrentMode)

    ; Start monitoring thread
    Local $hMonitor = Threading.Thread(_MonitorLoop)

    Log("Kiosk app running. Press F8 to exit.")

    ; Keep main thread alive
    While $g_bRunning
        Sleep(1000)
    WEnd
EndFunc

Func _ToggleMute()
    $g_bMuted = Not $g_bMuted
    ; Send mute key to all Chrome windows (Ctrl+Shift+M or via JS)
    ; This is a placeholder — Chrome app mode doesn't respond to global keys easily
    Log("Mute toggled: " & ($g_bMuted ? "Muted" : "Unmuted"))
EndFunc

Func _ExitKiosk()
    Log("Exiting kiosk...")
    _KillBrowsers()
    $g_bRunning = False
    Exit
EndFunc

;----------------------------------------------------------------------------------
; Run
;----------------------------------------------------------------------------------
Main()
