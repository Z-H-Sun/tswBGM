#!/usr/bin/env ruby
# encoding: ASCII-8Bit

require 'win32/api'
include Win32
PeekMessage = API.new('PeekMessage', 'PLLLI', 'I', 'user32')
SendMessage = API.new('SendMessage', 'LLLP', 'L', 'user32')
OpenProcess = API.new('OpenProcess', 'LLL', 'L', 'kernel32')
ReadProcessMemory = API.new('ReadProcessMemory', 'LLPLL', 'L', 'kernel32')
WriteProcessMemory = API.new('WriteProcessMemory', 'LLPLL', 'L', 'kernel32')
CloseHandle = API.new('CloseHandle', 'L', 'L', 'kernel32')
GetWindowThreadProcessId = API.new('GetWindowThreadProcessId', 'LP', 'L', 'user32')
MessageBox = API.new('MessageBoxA', 'LSSI', 'L', 'user32')
MessageBoxW = API.new('MessageBoxW', 'LSSI', 'L', 'user32')
IsWindow = API.new('IsWindow', 'L', 'L', 'user32')
FindWindow = API.new('FindWindow', 'SL', 'L', 'user32')
GetLastActivePopup = API.new('GetLastActivePopup', 'L', 'L', 'user32')
ShowWindow = API.new('ShowWindow', 'LI', 'L', 'user32')
EnableWindow = API.new('EnableWindow', 'LI', 'L', 'user32')
SetForegroundWindow = API.new('SetForegroundWindow', 'L', 'L', 'user32')
RegisterHotKey = API.new('RegisterHotKey', 'LILL', 'L', 'user32')
UnregisterHotKey = API.new('UnregisterHotKey', 'LI', 'L', 'user32')
MsgWaitForMultipleObjects = API.new('MsgWaitForMultipleObjects', 'LSILL', 'I', 'user32')

SW_HIDE = 0
SW_SHOW = 4 # SHOWNOACTIVATE
WM_SETTEXT = 0xC
WM_GETTEXT = 0xD
WM_COMMAND = 0x111
WM_HOTKEY = 0x312
IDOK = 1
IDCANCEL = 2
IDYES = 6
IDNO = 7
MB_OKCANCEL = 0x1
MB_YESNOCANCEL = 0x3
MB_ICONQUESTION = 0x20
MB_ICONEXCLAMATION = 0x30
MB_ICONASTERISK = 0x40
MB_DEFBUTTON2 = 0x100
MB_SETFOREGROUND = 0x10000
PROCESS_VM_WRITE = 0x20
PROCESS_VM_READ = 0x10
PROCESS_VM_OPERATION = 0x8
PROCESS_SYNCHRONIZE = 0x100000
POINTER_SIZE = [nil].pack('p').size
case POINTER_SIZE
when 4 # 32-bit ruby
  MSG_INFO_STRUCT = 'L7'
  HANDLE_ARRAY_STRUCT = 'L*'
when 8 # 64-bit
  MSG_INFO_STRUCT = 'Q4L3'
  HANDLE_ARRAY_STRUCT = 'Q*'
else
  raise 'Unsupported system or ruby version (neither 32-bit or 64-bit).'
end
TSW_CLS_NAME = 'TTSW10'
BASE_ADDRESS = 0x400000
OFFSET_EDIT8 = 0x1c8 # status bar textbox at bottom
OFFSET_HWND = 0xc0
OFFSET_OWNER_HWND = 0x20
TTSW_ADDR = 0x8c510 + BASE_ADDRESS
TAPPLICATION_ADDR = 0x8a6f8 + BASE_ADDRESS
STATUS_ADDR = 0xb8688 + BASE_ADDRESS
STATUS_INDEX = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 9] # floor-4; x-6; y-7
MAP_ADDR = 0xb8934 + BASE_ADDRESS
MIDSPEED_MENUID = 33 # The idea is to hijack the midspeed menu
MIDSPEED_ADDR = 0x7f46d + BASE_ADDRESS # so once click event of that menu item is triggered, arbitrary code can be executed
MIDSPEED_ORIG = 0x6F # original bytecode (call TTSW10.speedmiddle@0x47f4e0)
$buf = "\0" * 640
require './strings'
module Win32
  class API
    def self.focusTSW()
      ShowWindow.call($hWnd, SW_SHOW)
      hWnd = GetLastActivePopup.call($hWndTApp) # there is a popup child
      ShowWindow.call(hWnd, SW_SHOW) if hWnd != $hWnd
      SetForegroundWindow.call(hWnd) # SetForegroundWindow for $hWndTApp can also achieve similar effect, but can sometimes complicate the situation, e.g., LastActivePopup will be $hWndTApp if no mouse/keyboard input afterwards
      return hWnd
    end
    def self.msgbox(text, flag=MB_ICONASTERISK, api=(ansi=true; MessageBox), title=$appTitle)
      if IsWindow.call($hWnd || 0).zero?
        hWnd = $hWnd = 0 # if the window has gone, create a system level msgbox
      else
        hWnd = focusTSW()
      end
      title = (ansi ? 'tswBGM' : "t\0s\0w\0B\0G\0M\0\0") unless $appTitle
      return api.call(hWnd, text, title, flag | MB_SETFOREGROUND)
    end
    def call_r(*argv) # provide more info if a win32api returns null
      r = call(*argv)
      return r if $preExitProcessed # do not throw error if ready to exit
      if function_name == 'MsgWaitForMultipleObjects'
        return r if r >= 0 # WAIT_FAILED = (DWORD)0xFFFFFFFF
      else
        return r unless r.zero?
      end
      err = '0x%04X' % API.last_error
      case function_name
      when 'OpenProcess', 'WriteProcessMemory', 'ReadProcessMemory', 'VirtualAllocEx'
        reason = "Cannot open / read from / write to / alloc memory for the TSW process. Please check if TSW V1.2 is running with pID=#{$pID} and if you have proper permissions."
      when 'RegisterHotKey'
        reason = "Cannot register hotkey. It might be currently occupied by other processes or another instance of tswBGM. Please close them to avoid confliction. Default: F8 (119); current: (#{CON_MODIFIER}+ #{CON_HOTKEY}). As an advanced option, you can manually assign `CON_MODIFIER` and `CON_HOTKEY` in `#{APP_SETTINGS_FNAME}'."
      else
        reason = "This is a fatal error. That is all we know."
      end
      raise_r("Err #{err} when calling `#{effective_function_name}'@#{dll_name}.\n#{reason} tswSL has stopped. Details are as follows:\n\nPrototype='#{prototype.join('')}', ReturnType='#{return_type}', ARGV=#{argv.inspect}")
    end
  end
end
def readMemoryDWORD(address)
  ReadProcessMemory.call_r($hPrc, address, $buf, 4, 0)
  return $buf.unpack('l')[0]
end
def writeMemoryDWORD(address, dword)
  WriteProcessMemory.call_r($hPrc, address, [dword].pack('l'), 4, 0)
end
def callFunc(address) # execute the subroutine at the given address
  writeMemoryDWORD(MIDSPEED_ADDR, address-MIDSPEED_ADDR-4)
  SendMessage.call($hWnd, WM_COMMAND, MIDSPEED_MENUID, 0)
  writeMemoryDWORD(MIDSPEED_ADDR, MIDSPEED_ORIG) # restore
end
def msgboxTxtA(textIndex, flag=MB_ICONASTERISK, *argv)
  API.msgbox(Str::StrEN::STRINGS[textIndex] % argv, flag)
end
def msgboxTxtW(textIndex, flag=MB_ICONASTERISK, *argv)
  API.msgbox(Str.utf8toWChar(Str::StrCN::STRINGS[textIndex] % argv), flag, MessageBoxW)
end

VirtualAllocEx = API.new('VirtualAllocEx', 'LLLLL', 'L', 'kernel32')
VirtualFreeEx = API.new('VirtualFreeEx', 'LLLL', 'L', 'kernel32')
GetModuleHandle = API.new('GetModuleHandle', 'I', 'L', 'kernel32')
LoadImage = API.new('LoadImage', 'LLIIII', 'L', 'user32')
CreateWindowEx = API.new('CreateWindowEx', 'LSSLIIIILLLL', 'L', 'user32')
SetWindowText = API.new('SetWindowTextA', 'LS', 'L', 'user32')
SetWindowTextW = API.new('SetWindowTextW', 'LS', 'L', 'user32')
TranslateMessage = API.new('TranslateMessage', 'P', 'L', 'user32')
DispatchMessage = API.new('DispatchMessage', 'P', 'L', 'user32')
MEM_COMMIT = 0x1000
MEM_RESERVE = 0x2000
MEM_RELEASE = 0x8000
PAGE_EXECUTE_READWRITE = 0x40
QS_ALLINPUT = 0x4FF
QS_TIMER = 0x10
QS_ALLBUTTIMER = QS_ALLINPUT & ~QS_TIMER
WAIT_TIMEOUT = 258

LR_SHARED = 0x8000
IMAGE_ICON = 1
ICON_BIG = 1
WS_POPUP = 0x80000000
WS_CHILD = 0x40000000
WS_VISIBLE = 0x10000000
WS_BORDER = 0x800000
WS_EX_LAYERED = 0x80000
WS_EX_TOOLWINDOW = 0x80
WS_EX_TOPMOST = 8
SS_SUNKEN = 0x1000
SS_NOTIFY = 0x100
SS_ICON = 3
SS_RIGHT = 2
STM_SETICON = 0x170
WM_SETICON = 0x80
WM_LBUTTONDOWN = 0x201
WM_MBUTTONDBLCLK = 0x209 # b/w 0x201 and 209 are mouse events

MAX_PATH = 260

OFFSET_PARENT = 0x4 # similar to OFFSET_OWNER (0x20) but for TTimer that is not applicable
OFFSET_TTIMER_ENABLED = 0x20 # byte
OFFSET_TTIMER_INTERVAL = 0x24 # dword
OFFSET_TMEDIAPLAYER_PLAYSTATE = 0x1d5 # byte
OFFSET_TMEDIAPLAYER_DEVICEID = 0x1e6 # word
OFFSET_TMEDIAPLAYER5 = 0x2d8
OFFSET_TMEDIAPLAYER6 = 0x46c
OFFSET_TTIMER4 = 0x41c
OFFSET_TMENUITEM_BGMON1 = 0x330

BGM_SETTING_ADDR = 0x89ba2 + BASE_ADDRESS # byte
BGM_ID_ADDR = 0xb87f0 + BASE_ADDRESS
BGM_CHECK_ADDR = 0x7c8f8 + BASE_ADDRESS # TTSW10.soundcheck
BGM_PLAY_ADDR = 0x7c2bc + BASE_ADDRESS # TTSW10.soundplay
BGM_PLAY_OPEN_N_PLAY_ADDR = 0x7c6d3 + BASE_ADDRESS # place to jump to within TTSW10.soundplay
BGM_BASENAME_ADDR = 0x7c72a + BASE_ADDRESS # e.g. b_067xgw.mig
BGM_BASENAME_GAP = 0x1c # each separated by 0x1c bytes
DATA_CHECK1_ADDR = 0xb8918 + BASE_ADDRESS
DATA_CHECK2_ADDR = 0xb891c + BASE_ADDRESS

TTIMER4_ONTIMER_ADDR = 0x82a98 + BASE_ADDRESS # TTSW10.timer4ontimer
TTIMER_SETENABLED_ADDR = 0x2c454 + BASE_ADDRESS # _Unit9.TTimer.SetEnabled
TMEDIAPLAYER_CLOSE_ADDR = 0x31188 + BASE_ADDRESS # _Unit10.TMediaPlayer.Close
TMENUITEM_SETCHECKED_ADDR = 0x102f0 + BASE_ADDRESS # Menus.TMenuItem.SetChecked
MCISENDCOMMAND_ADDR = 0x2f838 + BASE_ADDRESS # winmm.mciSendCommandA

CLOSE_HANDLE_ADDR = 0x1228 + BASE_ADDRESS
WRITE_FILE_ADDR = 0x1290 + BASE_ADDRESS

APP_SETTINGS_FNAME = 'tswBGMdebug.txt'
APP_ICON_ID = 1 # Icons will be shown in the GUI of this app; this defines the integer identifier of the icon resource in the executable
CON_MODIFIER = 0
CON_HOTKEY = 119 # F8
BGM_DIRNAME = 'BGM' # the folder that contains the mp3 BGM files
BGM_FADE_STEPS = 10 # fade out BGM in 10 steps; 1 means no fading out effect
BGM_FADE_INTERVAL = 150 # each step takes 150 ms
INTERVAL_REHOOK = 450 # the interval for rehook (in msec)
INTERVAL_QUIT = 50 # for quit (in msec)
INTERVAL_TSW_RECHECK = 500 # the interval for checking TSW status

$BGMtakeOver = true

module BGM
  MCI_CLOSE = 0x804
  MCI_SETAUDIO = 0x873
  MCI_DGV_SETAUDIO_VOLUME = 0x4002
  MCI_DGV_SETAUDIO_ITEM = 0x800000
  MCI_DGV_SETAUDIO_VALUE = 0x1000000
  MCI_DGV_SETAUDIO_ITEM_VALUE = MCI_DGV_SETAUDIO_ITEM | MCI_DGV_SETAUDIO_VALUE

  BGM_CHECK_EXT = [ # floor; y,x of fairy; y,x,type to check (4=gate; 91=Zeno); boss battle BGM id; offset of jnz, jmp
 [10, 2, 5, 6, 5, 4, 15, 0x12, 0x5a], [20, 4, 5, 8, 5, 4, 16, 0x12, 0x43], [25, 6, 5, 9, 5, 4, 7, 0x12, 0x2c],
 [40, 5, 5, 7, 5, 4, 18, 0x12, 0x15], [49, 1, 5, 2, 5, 91, 19, -0x69, nil]]
  BGM_PHANTOMFLOOR = 'b_095xgw'
  BGM_PATCH_BYTES_0 = [ # address, len, original bytes, patched bytes
[0x4312cb, 65, "\x80\xBB\xE2\1\0\0\0\x74\x17\x80\xBB\xE0\1\0\0\0\x74\7\x83\x8B\xDC\1\0\0\2\xC6\x83\xE2\1\0\0\0\0\xBB\xE4\1\0\0\0\x74\x18\x83\x8B\xDC\1\0\0\4\x8B\x83\xF0\1\0\0\x89\x44\x24\4\xC6\x83\xE4\1\0\0\0", "\x8B\x43\4\x3B\x98\xD8\2\0\0\x74\x3D\x31\xD2\x89\x54\x24\4\5\x64\4\0\0\x3B\x18\x74\x1F\x3B\x58\xFC\xB2\4\x74\2\xB2\x40\xB8\x3B\xA1\x4B\0\x8A\x08\x39\x15\xAC\xC5\x48\0\x0F\x9F\0\x7F\x0C\x84\xC9\x75\x08\x83\x8B\xDC\1\0\0\4\x90"] # TMediaPlayer.Play
  ] # this list: always patch
  BGM_PATCH_BYTES = [ # address, len, original bytes, patched bytes[, variable to insert into patched bytes[, if `call relative`, an additional offset parameter is provided next]]
[TTIMER4_ONTIMER_ADDR, 1, "\xc3", "\xc3"], # temporarily disable TTimer4 (otherwise, there might be a relatively low chance, esp. for some PCs with rubbish performance, that the Timer4OnTimer event is running at the same time as tswBGM is patching the asm codes, thus confused and leading to heap corruption)

[0x430ef8, 9, 'Sequencer', 'MPEGVideo'], # lpstrDeviceType Sequencer=midi; MPEGVideo=mp3

[0x4508a9, 1, "\x75", "\x7B"], # TTSW10.itemlive redefine TTimer4.Enabled (jne -> jnp)
[0x4556be, 1, "\x75", "\x7B"], # TTSW10.syokidata2_1 redefine TTimer4.Enabled
[0x4556d2, 1, "\x85", "\x8B"], # TTSW10.syokidata2_2 redefine TTimer4.Enabled
[0x4558d9, 1, "\x85", "\x8B"], # TTSW10.syokidata2_3 redefine TTimer4.Enabled
[0x455af1, 1, "\x75", "\x7B"], # TTSW10.syokidata2_4 redefine TTimer4.Enabled
[0x455b40, 1, "\x75", "\x7B"], # TTSW10.syokidata2_5 redefine TTimer4.Enabled
[0x4637f5, 1, "\x75", "\x7B"], # TTSW10.GameStart1Click redefine TTimer4.Enabled
[0x47c2a3, 1, "\x75", "\x7B"], # TTSW10.BGMOn1Click redefine TTimer4.Enabled
[0x480efb, 1, "\x75", "\x7B"], # TTSW10.MouseControl1Click redefine TTimer4.Enabled

[0x48468e, 1, "\x85", "\x86"], # TTSW10.opening9 (ending scene) disregard BGMOn1.Checked
[0x46b640, 1, "\x74", "\xEB"], # TTSW10.moncheck for 49F (from battle with sorcerers); disregard stopping BGM (1,6,0)
[0x453463, 1, "\x74", "\xEB"], # TTSW10.stackwork for 11,7,0 (from opening2 (3f opening scene)); disregard playing BGM No.11 (will handle elsewhere)
[0x47ebda, 4, "\x76\x56\xF8\xFF", '%s', :@_sub_save_excludeBGM, 4], # TTSW10.savework do not save BGM_ID into data
[0x47ec67, 4, "\xE9\x55\xF8\xFF", '%s', :@_sub_save_excludeBGM, 4], # same above
[TTIMER_SETENABLED_ADDR, 5, "\x3A\x50\x20\x74\x08", "\xE8%s", :@_sub_resetTTimer4, 5], # _Unit9.TTimer.SetEnabled reset TTimer4 attributes for tswBGM
[BGM_CHECK_ADDR, 5, "\xA1\x98\x86\x4B\0", "\xE8%s", :@_sub_checkBGM_ext, 5], # TTSW10.soundcheck add more checks such as HP and boss battle
[0x45282a, 4, "\x8E\x9A\2\0", '%s', :@_sub_instruct_playBGM, 4], # TTSW10.stackwork for 1,5,0 -> with 1,5,bgmid; call sub_instruct_playBGM instead of sub_soundplay
[0x481f6f, 4, "\x15\xF2\xFA\xFF", '%s', :@_sub_checkOrbFlight, 4], # TTSW10.img4work; OrbOfFlight rather than always stopping BGM, check if it is necessary
[0x44edb9, 17, "\x74\x08\xFF\5\x98\x86\x4B\0\xEB\7\x83\5\x98\x86\x4B\0\2", "\xB8\x98\x86\x4B\0\x75\2\xFF\0\xFF\0\xE8%s\x90", :@_sub_checkOrbFlight, 16], # TTSW10.Button8Click (UP); check if need to stop BGM
[0x44ed39, 17, "\x74\x08\xFF\x0D\x98\x86\x4B\0\xEB\7\x83\x2D\x98\x86\x4B\0\2", "\xB8\x98\x86\x4B\0\x75\2\xFF\x08\xFF\x08\xE8%s\x90", :@_sub_checkOrbFlight, 16], # TTSW10.Button9Click (DOWN); check if need to stop BGM
[0x4618a1, 17, "\x74\x08\xFF\5\x98\x86\x4B\0\xEB\7\x83\5\x98\x86\x4B\0\2", "\xB8\x98\x86\x4B\0\x75\2\xFF\0\xFF\0\xE8%s\x90", :@_sub_checkOrbFlight, 16], # TTSW10.timer3ontimer (MouseDown on TButton8); check if need to stop BGM
[0x4618d9, 17, "\x74\x08\xFF\x0D\x98\x86\x4B\0\xEB\7\x83\x2D\x98\x86\x4B\0\2", "\xB8\x98\x86\x4B\0\x75\2\xFF\x08\xFF\x08\xE8%s\x90", :@_sub_checkOrbFlight, 16], # TTSW10.timer3ontimer (MouseDown on TButton9); check if need to stop BGM
[0x482abb, 15, "\x83\xE8\x08\x72\x0C\x83\xE8\7\x72\x19\x83\xE8\6\x72\x26", "\x80\x3D%s\0\x75\x0A\x68\x28\x2E\x48\0\xE9", :@_isInProlog], # TTSW10.timer4ontimer_1
[0x482aca, 25, "\xEB\x34\xBA\x5E\1\0\0\x8B\x83\x1C\4\0\0\xE8\x88\x99\xFA\xFF\xEB\x22\xBA\xFA\0\0\0", "%s\xBA\x5E\1\0\0\x83\xE8\x08\x72\x0B\x83\xE8\7\x72\2\xEB\x11\x83\xEA\x64\x90", :@_sub_timer4ontimer_real, 4], # TTSW10.timer4ontimer_2

[0x46f972, 1, "\0", "\x10"], # TTSW10.ichicheck for 20F (from battle with vampire); specify BGM id=16 (see sub_instruct_playBGM)
[0x476ead, 1, "\0", "\x13"], # TTSW10.ichicheck for 49F (from battle with sorcerers); specify BGM id=19 (see sub_instruct_playBGM)

[0x463e78, 2, "\xC7\5", "\xEB\x0F"], # TTSW10.mevent for 25F (from battle with archsorcerer); disregard playing BGM No.7 (will handle elsewhere)
[0x463f71, 2, "\xC7\5", "\xEB\x0F"], # TTSW10.mevent for 40F (from battle with knights); disregard playing BGM No.18 (will handle elsewhere)

[0x444d0e, 37, "\x83\x3D\xF0\x87\x4B\0\0\x74\x1E\x33\xD2\x8B\x45\xFC\x8B\x80\xB4\1\0\0\xE8\x2D\x77\xFE\xFF\x8B\x45\xFC\x8B\x80\xD8\2\0\0\xE8\x53\xC4", "\xEB\x25\x83\x3D\xF0\x87\x4B\0\0\x74\x15\xE8\xDA\x7B\3\0\x8B\x45\xFC\x8B\x80\x1C\4\0\0\xB2\6\xE8\x26\x77\xFE\xFF\xE9\x89\x42\0\0"], # TTSW10.handan for tileID=11/12 (stairs); soundcheck and soundplay
[0x445097, 4, "\x21\x3F\0\0", "\x75\xFC\xFF\xFF"], # TTSW10.handan for tileID=11/12 (stairs); jump to 444d0e

[0x430f83, 37, "\x89\x86\xDC\1\0\0\x80\xBE\xE2\1\0\0\0\x74\x1C\x80\xBE\xE0\1\0\0\0\x74\x0A\xC7\x86\xDC\1\0\0\2\0\0\0\xC6\x86\xE2", "\xB0\2\x89\x86\xDC\1\0\0\x8B\x46\4\x3B\xB0\xD8\2\0\0\x75\x22\xC7\x45\xF8%s\x66\x81\x8E\xDC\1\0\0\0\2\xEB\x10", :@_bgm_filename], # TMediaPlayer.Open
[TMEDIAPLAYER_CLOSE_ADDR, 64, "\x53\x56\x51\x8B\xD8\x66\x83\xBB\xE6\1\0\0\0\x0F\x84\xAD\0\0\0\x33\xC0\x89\x83\xDC\1\0\0\x80\xBB\xE2\1\0\0\0\x74\x1C\x80\xBB\xE0\1\0\0\0\x74\x0A\xC7\x83\xDC\1\0\0\2\0\0\0\xC6\x83\xE2\1\0\0\0\xEB\x0A", "\x8B\x50\4\x3B\x82\xD8\2\0\0\x75\x22\x8B\x82\x1C\4\0\0\xB2\6\xC6\5\xF0\x87\x4B\0\xFF\x80\x3D%s\0\x0F\x84\xA5\xB2\xFF\xFF\x53\xE9\x75\x26\3\0\x66\x83\xB8\xE6\1\0\0\0\x75\1\xC3\x53\x56\x51\x8B\xD8\x90\x90\x90", :@_isInProlog], # TMediaPlayer.Close
[0x431312, 15, "\0\x74\x18\x83\x8B\xDC\1\0\0\x08\x8B\x83\xEC\1\0", "\1\x75\x18\x81\x8B\xDC\1\0\0\0\0\1\0\xEB\x0C"], # TMediaPlayer.Play

[BGM_PLAY_ADDR, 13, "\x55\x8B\xEC\x6A\0\x53\x56\x57\x8B\xD8\x33\xC0\x55", "\x8B\x80\x1C\4\0\0\xB2\6\xE9\x8B\1\xFB\xFF"], # TTSW10.soundplay
[0x47c960, 20, "\xC7\5\xF0\x87\x4B\0\x09\0\0\0\xC3\xC7\5\xF0\x87\x4B\0\x0A\0\0", "\x83\xC0\6\x74\3\xB0\xF3\x90\4\x0C\x90\4\x0A\x0F\xB6\xC0\xA3\xF0\x87\x4B"], # TTSW10.soundcheck

[TTIMER4_ONTIMER_ADDR, 1, "\x55", "\x55"], # re-enable TTimer4 (see Line 51)

# battle w Skeletons
[0x46754c, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0A\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x0C\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\x0A\0"], # TTSW10.moncheck
[0x46f2e3, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0A\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x0F\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\x0A\0"], # TTSW10.ichicheck

# battle w Vampire
[0x4686ed, 67, "\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0A\0\x8B\3\x8D\4\x40", "\xC7\x44\x46\2\5\0\x0C\0\x31\xD2\xEB\4\x31\xD2\xEB\x1B\x83\3\2\x89\x54\x46\x12\x66\x89\x54\x46\x16\xC7\x44\x46\x18\1\0\5\0\x66\xC7\x44\x46\x1C\xFF\1\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\x0A\0\x15\0\xEB\x0C"], # TTSW10.moncheck

# battle w Archsorcerer
[0x468bb6, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\6\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x0C\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\6\0"], # TTSW10.moncheck
[0x4727df, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0A\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\7\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\x0A\0"], # TTSW10.ichicheck

# battle w Knights
[0x46ab26, 12, "\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0", "\xC7\x44\x46\2\5\0\x0C\0\x90\x90\x90\x90"], # TTSW10.moncheck
[0x473fb4, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\6\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\6\0\x66\xC7\x44\x46\4\0\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\6\0"], # TTSW10.ichicheck
[0x475eaa, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0A\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x12\0\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\x0A\0"], # TTSW10.ichicheck

# battle w Sorcerers
[0x46bf97, 12, "\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0", "\xC7\x44\x46\2\5\0\x0C\0\x90\x90\x90\x90"], # TTSW10.moncheck

# 42F Zeno-GKnight event
[0x47600b, 60, "\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\1\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2", "\x31\xD2\x83\x3D\xF0\x87\x4B\0\0\x74\x1D\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x09\1\x83\3\2\x83\xC0\6\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\4\x46\1\0"], # TTSW10.ichicheck
[0x476853, 23, "\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0\x8B\3\x8D\4\x40", "\xC7\4\x46\0\0\0\0\x83\x3D\xF0\x87\x4B\0\0\x74\7\xC7\4\x46\1\0\6\0"], # TTSW10.ichicheck

# 50F 1st-round Zeno event
[0x446571, 60, "\x66\xC7\4\x46\0\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\4\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0B\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\x0C\0\x8B\3\x8D\4\x40", "\x83\x3D\xF0\x87\x4B\0\0\x74\x13\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x14\0\xFF\3\x83\xC0\3\xC7\4\x46\0\0\4\0\x66\xC7\x44\x46\4\0\0\xFF\3\x83\xC0\3\x66\xC7\4\x46\x0B\0\x66\xC7\x44\x46\2\x0C\0"], # TTSW10.handan
# 24F "gate of space and time"
[0x470e32, 23, "\x8B\3\x8D\4\x40\x66\xC7\4\x46\x0F\0\x8B\3\x8D\4\x40\x66\xC7\x44\x46\2\0\0", "\x8B\x14\x46\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x0A\1\x83\xC0\3\x89\x14\x46"], # TTSW10.ichicheck

# 50F >=2nd-round Zeno event
[0x46cac5, 61,
"\x8B\x03\x8D\x04\x40\x66\xC7\x44\x46\x02\x00\x00\x8B\x03\x8D\x04\x40\x66\xC7\x44\x46\x04\x00\x00\xFF\x03\x8B\x03\x8D\x04\x40\x66\xC7\x04\x46\x0A\x00\x8B\x03\x8D\x04\x40\x66\xC7\x44\x46\x02\x3E\x00\x8B\x03\x8D\x04\x40\x66\xC7\x44\x46\x04\x63\x00", "\x31\xD2\x89\x54\x46\x02\xFF\x03\x83\xC0\x03\xC7\x04\x46\x0A\x00\x3E\x00\x66\xC7\x44\x46\x04\x63\x00\x83\x3D\xF0\x87\x4B\x00\x00\x74\x1B\x83\x03\x02\x83\xC0\x06\x89\x54\x46\xFA\x66\x89\x54\x46\xFE\xC7\x04\x46\x01\x00\x06\x00\x66\x89\x54\x46\x04"], # TTSW10.moncheck

# 3F Zeno event
[0x46431d, 45, "\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x66\xC7\x44\x46\2\0\0\x66\xC7\x44\x46\4\0\0\xFF\3\x8B\3\x8D\4\x40\x66\xC7\4\x46\0\0\x66\xC7\x44\x46\2\0\0", "\x83\xC0\3\x83\x3D\xF0\x87\x4B\0\0\x74\x28\xC7\4\x46\1\0\5\0\x66\xC7\x44\x46\4\x0B\1\x83\3\2\x83\xC0\3\x31\xD2\x89\x14\x46\x89\x54\x46\4\x89\x54\x46\x08"], # TTSW10.opening2
# 2F Zeno event aftermath
[0x44dc78, 38, "\x33\xC0\xA3\xAC\xC5\x48\0\x8B\xC3\xE8\xB2\x4F\xFF\xFF\x33\xD2\x8B\x83\xCC\1\0\0\xE8\x6D\x58\xFC\xFF\x33\xD2\x8B\x83\xCC\1\0\0\xE8\x34\x59", "\xA3\xAC\xC5\x48\0\x8B\xC3\xE8\xB4\x4F\xFF\xFF\x8B\x15\xF0\x87\x4B\0\x85\xD2\x74\7\xB2\5\xE8%s\x8B\x83\xCC\1\0\0\xE8\x60\x58", :@_sub_instruct_playBGM_direct, 29] # TTSW10.Button1Click (OK)
]

  class << self
    attr_reader :bgm_path
    attr_reader :_bgm_filename
    attr_reader :_bgm_basename
  end
  module_function
  def init
    BGM_PATCH_BYTES_0.each {|i| WriteProcessMemory.call_r($hPrc, i[0], i[3], i[1], 0)} # must-do patches
    @bgm_path = $BGMpath
    bgm_basename = BGM_PHANTOMFLOOR + '.mp3'
    unless @bgm_path
      if File.exist?(BGM_DIRNAME+'/'+bgm_basename) # find in current dir
        @bgm_path = CUR_PATH
      else # find in app dir
        @bgm_path = APP_PATH
      end
      @bgm_path.encode!('filesystem').force_encoding('ASCII-8Bit') if String.instance_methods.include?(:encoding) # this is necessary for Ruby > 1.9
      @bgm_path += '/'+BGM_DIRNAME
    end
    @bgm_path = @bgm_path[0, 2].gsub('/', "\\") + @bgm_path[2..-1].gsub(/[\/\\]+/, "\\").sub(/\\?$/, "\\") # normalize file path (changing / into \; reducing multiple consecutive slashes into 1; always add a tailing \); the first 2 chars might be \\ which should not be reduced
    bgm_filename = @bgm_path + bgm_basename
    bgm_filename_enc = bgm_filename.dup
    bgm_filename_enc.force_encoding('filesystem') if String.instance_methods.include?(:encoding) # this is necessary for Ruby > 1.9
    bgmsize = bgm_filename.size
    return raiseInvalDir(26) if bgmsize > MAX_PATH-2 # MAX_PATH includes the tailing \0
    return raiseInvalDir(27) unless File.exist?(bgm_filename_enc)

    fadeStrength = 999 / BGM_FADE_STEPS + 1 # i.e. (1000.0 / BGM_FADE_STEPS).ceil

    # the first 0xa00 bytes are reserved for tswSL
    # these are all pointers to the corresponding variables:
    @_bgm_filename = $lpNewAddr + 0xa00
    @_bgm_basename = @_bgm_filename + bgmsize - 12
    @_bgm_phantomfloor = $lpNewAddr + 0xb04
    @_isInProlog = $lpNewAddr + 0xb0c
    @_last_bgmid = $lpNewAddr + 0xb10
    @_mci_params = $lpNewAddr + 0xb14
    @_mci_params_volume = @_mci_params + 8
    offset_sub_soundplay_real = 0xb20
    @_sub_soundplay_real = $lpNewAddr + offset_sub_soundplay_real
    @_sub_timer4ontimer_real = $lpNewAddr + 0xb64
    @_sub_instruct_playBGM = $lpNewAddr + 0xc00
    @_sub_instruct_playBGM_direct = @_sub_instruct_playBGM + 11
    @_sub_checkOrbFlight = $lpNewAddr + 0xc38
    @_sub_checkBGM_ext = $lpNewAddr + 0xc64
    @_sub_resetTTimer4 = $lpNewAddr + 0xd0c
    @_sub_initBGM = $lpNewAddr + 0xd38
    @_sub_finalizeBGM = $lpNewAddr + 0xd90
    @_sub_save_excludeBGM = $lpNewAddr + 0xdd8

    injBuf = bgm_filename.ljust(MAX_PATH, "\0") + BGM_PHANTOMFLOOR +
[1, 0xff].pack('LL') + # 0B0C byte isInProlog; 0B10 byte last_bgmid
[0, MCI_DGV_SETAUDIO_VOLUME, 1000].pack('lll') + # 0B14 mci_params
# HWND dwCallback (no need); DWORD dwItem (volume); DWORD dwValue (volume fraction 0 to 1000)

# 0B20: subroutine soundplay_real
"\x55\x8B\xEC\x6A\0\x53\x56\x57\x8B\xD8\x31\xC0\x55\x68\x0C\xC7\x47\0\x64\xFF\x30\x64\x89\x20\xA1" +
[BGM_ID_ADDR, 0xc083, 0x83fb, 0x11f8, 0x1877, 0xbf, @_bgm_basename, 0xbe, @_bgm_phantomfloor,
 0x0974, 0xf06b, BGM_BASENAME_GAP, 0xc681, BGM_BASENAME_ADDR, 0xa5fc, 0xe9a5,
 BGM_PLAY_OPEN_N_PLAY_ADDR-$lpNewAddr-0xb62, 0x9090].pack('LSSSSCLCLSSCSLSSlS') + # 0B5D...0B62 jmp 47c6d3

# 0B64: subroutine timer4ontimer_real
[0xb8, @_mci_params, 0x7881, 8, 1000, 0x1b75, 0x158b, BGM_ID_ADDR, 0x153a, @_last_bgmid,
 0x0d75, 0x838b, OFFSET_TTIMER4, 0xd231, 0xe9, TTIMER_SETENABLED_ADDR-$lpNewAddr-0xb8d, # 0B88...0B8D jmp TTimer.SetEnabled
 0x6881, 8, fadeStrength, 0x7350, 0x6a09, 0x6800,
 MCI_CLOSE, 0x0aeb, 0x68, MCI_DGV_SETAUDIO_ITEM_VALUE, 0x68, MCI_SETAUDIO,
 0x838b, OFFSET_TMEDIAPLAYER5, 0xb70f, 0x80, OFFSET_TMEDIAPLAYER_DEVICEID,
 0xe850, MCISENDCOMMAND_ADDR-$lpNewAddr-0xbbd, # 0BB8...0BBD call winmm.mciSendCommandA
 0xc085, 0xb8, @_mci_params_volume, 0x0575, 0x3883, 0, 0x3479,
 0x00c7, 1000, 0x838b, OFFSET_TMEDIAPLAYER5, 0xd231, 0x9088, OFFSET_TMEDIAPLAYER_PLAYSTATE, 0x838b, OFFSET_TTIMER4,
 0xe8, TTIMER_SETENABLED_ADDR-$lpNewAddr-0xbea, # 0BE5...0BEA call TTimer.SetEnabled
 0xa1, BGM_ID_ADDR, 0xa2, @_last_bgmid, 0x013c, 0x0778, 0xc38b,
 0xe9, offset_sub_soundplay_real-0xbff, # 0BFA...0BFF jmp sub_soundplay_real
 0xc3].pack('CLSCLSSLSLSSLSClSCLSSSLSCLCLSLSCLSlSCLSSCSSLSLSSLSLClCLCLSSSClC') +

# 0C00: subroutine instruct_playBGM
"\x8B\x14\x4D\x50\xC7\x48\0\x84\xD2\x74\x2B\x88\x15" +
[BGM_ID_ADDR, 0xf684, 0x0b74, 0x838b, OFFSET_TMEDIAPLAYER6, 0xe8, TMEDIAPLAYER_CLOSE_ADDR-$lpNewAddr-0xc20, # 0C1B...0C20 call TMediaPlayer.Close
 0x838b, OFFSET_TTIMER4, 0x06b2, 0xe8, TTIMER_SETENABLED_ADDR-$lpNewAddr-0xc2d, # 0C28...0C2D call TTimer.SetEnabled
 0xc38b, 0xe8, TTIMER4_ONTIMER_ADDR-$lpNewAddr-0xc34, # 0C2F...0C34 jmp TTSW10.timer4ontimer
 0xd231, 0x90c3].pack('LSSSLClSLSClSClSS') +

# 0C38: subroutine checkOrbFlight
[0xb9, BGM_ID_ADDR, 0xba, @_last_bgmid, 0x3980, 0x7801, 0xe81b,
 BGM_CHECK_ADDR-$lpNewAddr-0xc4c].pack('CLCLSSSl') + # 0C47...0C4C call TTSW10.soundcheck
"\x8A\2\x3A\1\x74\x10\xC6\1\xFF\xB2\6\x8B\x83" +
[OFFSET_TTIMER4, 0xe9, TTIMER_SETENABLED_ADDR-$lpNewAddr-0xc62, # 0C5D...0C62 jmp TTimer.SetEnabled
 0x90c3].pack('LClS') +

# 0C64: subroutine checkBGM_ext
[0xb8, STATUS_ADDR, 0x3883, 0, 0x0b75, 0x05c6, BGM_ID_ADDR].pack('CLSCSSL') +
"\x0E\x83\xC4\4\xC3\x8B\x40#{(STATUS_INDEX[4] << 2).chr}\x50" +
BGM_CHECK_EXT.map {|i| [0xf883, i[0], 0x75, i[7], 0xb8, 0, i[5], i[6], 0xa0,
 MAP_ADDR+123*i[0]+11*i[1]+i[2]+2, 0x258a, MAP_ADDR+123*i[0]+11*i[3]+i[4]+2,
 0xeb, i[8]].pack(i[8] ? 'SCCcCSCCCLSLCc' : 'SCCcCSCCCLSL')}.join +
"\x3C\x17\x75\4\xB0\x0C\xEB\x0C\xC1\xE8\x08\x38\xE0\x74\2\x58\xC3\xC1\xE8\x10\xA2" +
[BGM_ID_ADDR, 0xc483, 0xc308, 0x90].pack('LSSC') +

# 0D0C: subroutine resetTTimer4
[0x488b, OFFSET_PARENT, 0x813b, OFFSET_TTIMER4, 0x1575, 0x05c6, @_isInProlog,
 0xb900, BGM_FADE_INTERVAL, 0x483b, OFFSET_TTIMER_INTERVAL, 0x0474, 0x4889,
 OFFSET_TTIMER_INTERVAL, 0xc3, 0x503a, OFFSET_TTIMER_ENABLED, 0x0375, 0xc483,
 4, 0x90c3, 0x9090].pack('SCSLSSLSLSCSSCCSCSSCSS') +

# 0D38: subroutine initBGM
[0xd88b, 0x838b, OFFSET_TTIMER4, 0x408a, OFFSET_TTIMER_ENABLED, 0x0124, 0xa2,
 @_isInProlog, 0xba, BGM_ID_ADDR, 0x0374, 0x02c6, 21, 0x028a, 0x013c, 0x0779,
 0xe8, BGM_CHECK_ADDR-$lpNewAddr-0xd5f, # 0D5A...0D5F call TTSW10.soundcheck
 0x028a, 0xa2, @_last_bgmid, 0x838b, OFFSET_TMEDIAPLAYER5, 0x80c6,
 OFFSET_TMEDIAPLAYER_PLAYSTATE, 0x0f00, 0x80b7, OFFSET_TMEDIAPLAYER_DEVICEID,
 0x68, @_mci_params, 0x006a, 0x68, MCI_CLOSE, 0xe850, MCISENDCOMMAND_ADDR-$lpNewAddr-0xd8C, # 0D87...0D8C call winmm.mciSendCommandA
 0x01b2, 0x04eb].pack('SSLSCSCLCLSSCSSSClSCLSLSLSSLCLSCLSlSS') +

# 0D90: subroutine finalizeBGM
[0xd231, 0xd88b, 0x1588, BGM_SETTING_ADDR, 0x838b, OFFSET_TMENUITEM_BGMON1,
 0xe8, TMENUITEM_SETCHECKED_ADDR-$lpNewAddr-0xda5, # 0DA0...0DA5 callTMenuItem.SetChecked
 0xd231, 0x1538, BGM_SETTING_ADDR, 0x0774, 0xc38b, 0xe9, offset_sub_soundplay_real-0xdb6, # 0DB1...0DB6 jmp sub_soundplay_real
 0x1589, BGM_ID_ADDR, 0x838b, OFFSET_TMEDIAPLAYER5,
 0xe8, TMEDIAPLAYER_CLOSE_ADDR-$lpNewAddr-0xdc7, # 0DC2...0DC7 call TMediaPlayer.Close
 0x158a, @_isInProlog, 0x838b, OFFSET_TTIMER4, 0xe9,
 TTIMER_SETENABLED_ADDR-$lpNewAddr-0xdd8].pack('SSSLSLClSSLSSClSLSLClSLSLCl') + # 0DD3...0DD8 jmp TTimer.SetEnabled

# 0DD8: subroutine save_excludeBGM
"\x31\xFF\x8B\x18\x53\x8D\x44\x24\x08\x57\x50\x51\x52\x53\xB8" +
[BGM_ID_ADDR, 0x188b, 0x1d29, DATA_CHECK1_ADDR, 0x1d29,
 DATA_CHECK2_ADDR, 0x3889, 0xe8, WRITE_FILE_ADDR-$lpNewAddr-0xe00, # 0DFB...0E00 call kernel32.WriteFile
 0xe8, CLOSE_HANDLE_ADDR-$lpNewAddr-0xe05, # 0E00...0E05 call kernel32.CloseHandle
 0x1d89, BGM_ID_ADDR, 0x0483, 0x1424, 0xc2, 4].pack('LSSLSLSClClSLSSCS')

    WriteProcessMemory.call_r($hPrc, @_bgm_filename, injBuf, injBuf.size, 0)

    takeOverBGM(true) if $BGMtakeOver
  end
  def takeOverBGM(bEnable)
    BGM_PATCH_BYTES.each do |i|
      if bEnable
        d = i[3]
        if (p=i[4])
          v = instance_variable_get(p)
          if (o=i[5])
            v -= o+i[0]
          end
          d = d % [v].pack('l')
        end
      else
        d = i[2]
      end
      WriteProcessMemory.call($hPrc, i[0], d, i[1], 0)
    end
    if bEnable
      callFunc(@_sub_initBGM)
    else
      callFunc(@_sub_finalizeBGM)
    end
  end
  def raiseInvalDir(reason)
    if msgboxTxt(23, MB_ICONEXCLAMATION | MB_OKCANCEL, $str::STRINGS[reason]) == IDCANCEL
      preExit; msgboxTxt(13); exit
    end
    @bgm_path = nil
  end
end

def disposeRes() # when switching to a new TSW process, hDC and hPrc will be regenerated, and the old ones should be disposed of
  VirtualFreeEx.call($hPrc || 0, $lpNewAddr || 0, 0, MEM_RELEASE)
  CloseHandle.call($hPrc || 0)
  $appTitle = nil
end
def preExit() # finalize
  return if $preExitProcessed # do not exec twice
  $preExitProcessed = true
  begin
    BGM.takeOverBGM(false)
  rescue Exception
  end
  SendMessage.call($hWndText || 0, WM_SETTEXT, 0, '')
  UnregisterHotKey.call(0, 1)
  disposeRes()
end
def raise_r(*argv)
  preExit() # ensure all resources disposed
  raise(*argv)
end
def initLang()
  if $isCHN
    alias :msgboxTxt :msgboxTxtW
  else
    alias :msgboxTxt :msgboxTxtA
  end
end
def initSettings()
  load(File.exist?(APP_SETTINGS_FNAME) ? APP_SETTINGS_FNAME : File.join(APP_PATH, APP_SETTINGS_FNAME))
rescue Exception
end
def waitTillAvail(addr) # upon initialization of TSW, some pointers or handles are not ready yet; need to wait
  r = readMemoryDWORD(addr)
  while r.zero?
    case MsgWaitForMultipleObjects.call_r(1, $bufHWait, 0, INTERVAL_TSW_RECHECK, QS_ALLBUTTIMER)
    when 0 # TSW quits during waiting
      disposeRes()
      return
    when 1 # this thread's msg
      checkMsg(false)
    when WAIT_TIMEOUT
      r = readMemoryDWORD(addr)
    end
  end
  return r
end
def init()
  $hWnd = FindWindow.call(TSW_CLS_NAME, 0)
  $tID = GetWindowThreadProcessId.call($hWnd, $buf)
  $pID = $buf.unpack('L')[0]
  return if $hWnd.zero? or $pID.zero? or $tID.zero?

  initSettings()
  $hPrc = OpenProcess.call_r(PROCESS_VM_WRITE | PROCESS_VM_READ | PROCESS_VM_OPERATION | PROCESS_SYNCHRONIZE, 0, $pID)
  $bufHWait[0, POINTER_SIZE] = [$hPrc].pack(HANDLE_ARRAY_STRUCT)

  tApp = readMemoryDWORD(TAPPLICATION_ADDR)
  $hWndTApp = readMemoryDWORD(tApp+OFFSET_OWNER_HWND)
  $TTSW = readMemoryDWORD(TTSW_ADDR)
  return unless (edit8 = waitTillAvail($TTSW+OFFSET_EDIT8))
  return unless ($hWndText = waitTillAvail(edit8+OFFSET_HWND))

  ShowWindow.call($hWndStatic1, SW_HIDE)
  Str.isCHN()
  initLang()
  $appTitle = 'tswBGM - pID=%d' % $pID
  $appTitle = Str.utf8toWChar($appTitle) if $isCHN

  $lpNewAddr = VirtualAllocEx.call_r($hPrc, 0, 4096,MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE)
  BGM.init

  msgboxTxt(11)
  return true
end
def waitInit()
  ShowWindow.call($hWndStatic1, SW_SHOW)
  if $isCHN
    SetWindowTextW.call($hWndStatic1, Str.utf8toWChar(Str::StrCN::STRINGS[20]))
  else
    SetWindowText.call($hWndStatic1, Str::StrEN::STRINGS[20])
  end
  loop do # waiting while processing messages
    case MsgWaitForMultipleObjects.call_r(0, nil, 0, INTERVAL_TSW_RECHECK, QS_ALLBUTTIMER)
    when 0
      checkMsg(false)
    when WAIT_TIMEOUT
      break if init()
    end
  end
end
def checkMsg(checkAll=true)
  while !PeekMessage.call($buf, 0, 0, 0, 1).zero?
    msg = $buf.unpack(MSG_INFO_STRUCT)
    case msg[1]
    when WM_HOTKEY
      time = msg[4]
      diff = time - $time
      $time = time
      case msg[2]
      when 1
        if diff < INTERVAL_QUIT
          preExit; msgboxTxt(13); exit
        end
        if checkAll
          next if BGM.bgm_path.nil? # BGM files are not ready
          $BGMtakeOver = !$BGMtakeOver
          BGM.takeOverBGM($BGMtakeOver)
          SendMessage.call($hWndText, WM_SETTEXT, 0, 'tswBGM: You turned BGM optimization '+($BGMtakeOver ? 'on.':'off.'))
        else
          ShowWindow.call($hWndStatic1, SW_SHOW)
        end
        next
      end
    when WM_LBUTTONDOWN..WM_MBUTTONDBLCLK
      if msg[0] == $hWndStatic1
        case msgboxTxt(21, MB_YESNOCANCEL|MB_DEFBUTTON2|MB_ICONQUESTION)
        when IDYES
          preExit; msgboxTxt(13); exit
        when IDNO
          ShowWindow.call($hWndStatic1, SW_HIDE)
        end
     end
    end
    TranslateMessage.call($buf)
    DispatchMessage.call($buf)
  end
end

CUR_PATH = Dir.pwd
APP_PATH = File.dirname($Exerb ? ExerbRuntime.filepath : __FILE__) # after packed by ExeRB into exe, __FILE__ will be useless
initSettings()
initLang()
$time = 0
$bufHWait = "\0" * (POINTER_SIZE << 1)
$hMod = GetModuleHandle.call_r(0)
$hIco = LoadImage.call($hMod, APP_ICON_ID, IMAGE_ICON, 48, 48, LR_SHARED)
$hWndStatic1 = CreateWindowEx.call_r(WS_EX_TOOLWINDOW|WS_EX_TOPMOST, 'STATIC', nil, WS_POPUP|WS_BORDER|SS_SUNKEN|SS_NOTIFY|SS_RIGHT, 20, 20, 142, 52, 0, 0, 0, 0)
$hWndStatic2 = CreateWindowEx.call_r(0, 'STATIC', nil, WS_CHILD|WS_VISIBLE|SS_ICON, 0, 0, 48, 48, $hWndStatic1, 0, 0, 0)
SendMessage.call($hWndStatic2, STM_SETICON, $hIco, 0)

RegisterHotKey.call_r(0, 1, CON_MODIFIER, CON_HOTKEY)
waitInit() unless init()

loop do
  case MsgWaitForMultipleObjects.call_r(1, $bufHWait, 0, -1, QS_ALLBUTTIMER)
  when 0 # TSW has quitted
    disposeRes()
    waitInit()
    next
  when 1 # this thread's msg
    checkMsg()
  end
end
