#encoding: ASCII-8BIT
BASE_ADDRESS = 0x400000
OFFSETS = [0xb8698, 0xb86b8, 0x8c5c8, 0xb8688, 0x8c5ac, 0x8c748, 0x8c584] # floor, isMoving, dialog, hp, eventFlag1, eventFlag2, coordinate
# the event types @ certain position (0x4B8934+123*F+11*y+x+2, refer to subroutine_444490)
TYPES_ADDR = [0xb8e09, 0xb8e1f, 0xb932f, 0xb9303, # [F10, x5, y0], [F10, x5, y2], [F20, x5, y8], [F20, x5, y4]
              0xb94c3, 0xb95a1, 0xb9580, 0xb9cc0, # [F24, x5, y0], [F25, x5, y9], [F25, x5, y6], [F40, x5, y7]
              0xb9caa, 0xba0dc, 0xba0d1] # [F40, x5, y5], [F49, x5, y2], [F25, x2, y1]
TYPES = [4, 6, 7, 23, 81, 91] # gate, floor, trigger, fairy, skeleton c, zeno
THIS = $Exerb ? ExerbRuntime.filepath : __FILE__
PATH = File.exist?('BGM') ? 'BGM' : File.join(File.dirname(THIS), 'BGM') # find in 2 locations: pwd; the folder of the script
FILES = ['LuckyGold.mp3', 'Block1.mp3', 'Block2.mp3', 'Block3.mp3', 'Block4.mp3', 'Block5.mp3', 'LastBattle.mp3', 'AgainstSkeletonArmy.mp3', 'AgainstVampire.mp3', 'AgainstGreatMagicMaster.mp3', 'AgainstKnightArmy.mp3', 'AgainstZeno.mp3', 'Opening.mp3', 'Ending.mp3', 'Fairy.mp3', 'Princess.mp3', 'GameOver.mp3', 'PhantomFloor.mp3']

MODIFIER = 0
KEY = 119

QUIT_INTERVAL = 0.5 # if press hotkey twice within this long (or hold the hotkey), then quit (in sec)
TIMER_INTERVAL = 0.2 # check the TSW game status every xx sec

require 'Win32API'
class Win32API # add exception handling
  alias init initialize
  def initialize(*argv)
    @attr = argv
    init(*argv)
  end
  def call_r(*argv) # provide more info if a win32api returns null
    r = call(*argv)
    return r unless r.zero?
    err = '0x' + LST_ERR.call.to_s(16).upcase
    case @attr[1]
    when 'WriteProcessMemory', 'ReadProcessMemory'
      reason = "Cannot read from / write to the TSW process. Please check if TSW V1.2 is\nrunning with pID=#{$pID} and if you have proper permissions.\n"
    when 'OpenProcess'
      reason = "Cannot open the TSW process for writing. Please check if\nTSW V1.2 is running with pID=#{$pID} and if you have proper\npermissions. "
    when 'RegisterHotKey'
      reason = "Cannot register hotkey. It might be currently occupied by\nother processes or another instance of tswBGM. Please close\nthem to avoid confliction. Default: F8 (0+ 119); current:\n(#{MODIFIER}+ #{KEY}). As an advanced option, you can manually assign\nMODIFIER and KEY in `tswBGMdebug.txt'.\n\n"
    else
      reason = "This is a fatal error. That is all we know. "
    end
    raise("Err #{err} when calling `#{@attr[1]}'@#{@attr[0]}.\n#{reason}tswBGM has stopped. Details are as follows:\n\nPrototype='#{@attr[2]}', ReturnType='#{@attr[3]}', ARGV=#{argv.inspect}")
  end
end

MCI_EXE = Win32API.new('winmm','mciExecute','p','l')
PEEK_MESSAGE = Win32API.new('user32','PeekMessage','pllll','l')
SEND_MESSAGE = Win32API.new('user32', 'SendMessage', 'lllp', 'l')
REG_HOTKEY = Win32API.new('user32', 'RegisterHotKey', 'lill', 'l')
UNREG_HOTKEY = Win32API.new('user32', 'UnregisterHotKey', 'li', 'l')
OPEN_PROCESS = Win32API.new('kernel32', 'OpenProcess', 'lll', 'l')
READ_PROCESS = Win32API.new('kernel32', 'ReadProcessMemory', 'llplp', 'l')
WRITE_PROCESS = Win32API.new('kernel32', 'WriteProcessMemory', 'llplp', 'l')
MESSAGE_BOX = Win32API.new('user32', 'MessageBox', 'lppi', 'l')
FIND_WIN = Win32API.new('user32', 'FindWindowEx', 'llpl', 'l')
IS_WIN = Win32API.new('user32', 'IsWindow', 'l', 'l')
GET_RECT = Win32API.new('user32', 'GetClientRect', 'lp', 'l')
GET_FOC = Win32API.new('user32','GetFocus','','l')
ATT_INPUT = Win32API.new('user32', 'AttachThreadInput', 'iii', 'i')
GET_CLS = Win32API.new('user32', 'GetClassName', 'lpl', 'l')
WRITE_CON = Win32API.new('kernel32', 'WriteConsole', 'lpipl', 'l')
SET_CON = Win32API.new('kernel32', 'SetConsoleTitle', 'p', 'l')
GET_TID = Win32API.new('kernel32', 'GetCurrentThreadId', '', 'i')
LST_ERR = Win32API.new('kernel32', 'GetLastError', '', 'l')

PROCESS_VM_WRITE = 0x20
PROCESS_VM_READ = 0x10
PROCESS_VM_OPERATION = 0x8
MB_ICONEXCLAMATION = 0x30
MB_ICONINFORMATION = 0x40
STD_OUTPUT_HANDLE = -11
WM_COMMAND = 0x111
WM_SETTEXT = 0xC
QUIT_MENUID = 3 # The idea is to hijack the quit menu
QUIT_ADDR = 0x63874 + BASE_ADDRESS # so once click event of that menu item is triggered, arbitrary code can be executed
QUIT_ORIG = "\x6a\0\x66\x8B\x0D\xF0\x38\x46\0\xB2\2\xB8\xFC\x38" # original bytecode (push 0; mov cx, word ptr ds:[4638F0]; mov dl, 2;...)
MUTE_ADDR = 0x31188 + BASE_ADDRESS # mute the midiaplayer

Win32API.new('kernel32', 'AttachConsole', 'i', 'l').call(-1) # so that we can log verbose info in a console
$hCon = Win32API.new('kernel32', 'GetStdHandle', 'i', 'l').call(STD_OUTPUT_HANDLE)
$hWnd = $pID = $tID = 0
$BGM = true
begin
  load('tswBGMdebug.txt')
rescue Exception
end

REG_HOTKEY.call_r(0, 0, MODIFIER, KEY)

def log(str) # log in console output
  WRITE_CON.call($hCon, str, str.size, $bytesRead, 0)
end

def play() # play mp3
  log("Now playing: `#{$audio}'\n")
  SET_CON.call("tswBGM [pID=#{$pID}] - #{$audio}")
  return false if $audio.empty?
  f = File.join(PATH, $audio)
  ($audio = ''; return false) if MCI_EXE.call("open \"#{f}\" type MPEGVideo alias m").zero?
  ($audio = ''; return false) if MCI_EXE.call('play m repeat').zero? # stop if any fails
  return true
end

def fade() # fade out current bgm
  unless $audio.empty?
    $audio = ''
    SET_CON.call("tswBGM [pID=#{$pID}] - None")
    for i in 1..10 # fade out
      return false if MCI_EXE.call('setaudio m Volume to '+((10-i)*100).to_s).zero?
      sleep(TIMER_INTERVAL/2)
    end
    return false if MCI_EXE.call('close m').zero?
  end
  return true
end

def init()
  $audio = '' # music filename
  $floor = 99 # current floor #
  $waitBattle = false # if the battle with GreatMagicMaster or Zeno has ended
  $bytesRead = '    '
  $buf2 = "\0\0"
  $buf4 = "\0\0\0\0"
  $buf16 = ' '*16
  $gateOfST = false # if reach the gate of space and time?
  $epilogue = false # if the tower falls down?
  $firstCheck = true # we should run the first check since in that case we can't determine the current progress

  if $hWnd.zero? or $pID.zero? or $tID.zero?
    $hWnd = FIND_WIN.call(0, 0, 'TTSW10', 0)
    if $hWnd.zero? # TSW not open, wait...
      log(Time.now.strftime('[%H:%M:%S]')+" Waiting for TSW to load...\n")
      while $hWnd.zero?
        $hWnd = FIND_WIN.call(0, 0, 'TTSW10', 0)
        sleep(TIMER_INTERVAL)
      end
      $audio = FILES[0] if $BGM # the braveman is walking to save the princess...
      $firstCheck = false # we run tswBGM from the start, so no need to run first check
    end
    $pID = '\0\0\0\0'
    $tID = Win32API.new('user32', 'GetWindowThreadProcessId', 'lp', 'l').call($hWnd, $pID)
    $pID = $pID.unpack('L')[0]

    raise("Cannot find the TSW process or thread. Please check whether\nthis is really a TSW window? hWnd=#{$hWnd}. tswBGM has stopped.\n\nAs an advanced option, you can manually assign $hWnd, $tID\nand $pID in `tswBGMdebug.txt'; then restart tswBGM.") if $pID.zero? or $tID.zero?
  end
  $hPrc = OPEN_PROCESS.call_r(PROCESS_VM_READ | PROCESS_VM_OPERATION | PROCESS_VM_WRITE, 0, $pID)

  unless $audio.empty?  # the braveman is walking to save the princess...
    log(Time.now.strftime('[%H:%M:%S]')+' Loading the game... ')
    sleep(6) if play
    fade
  end
  if IS_WIN.call($hWnd).zero? # in case TSW is closed while sleeping
    log(Time.now.strftime('[%H:%M:%S]')+" TSW (pID=#{$pID}) has been closed.\n\n")
    $pID = $tID = 0
    fade; init
  else
    ATT_INPUT.call_r(GET_TID.call, $tID, 1) # This is necessary for GetFocus to work: 
    #https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getfocus#remarks
    MESSAGE_BOX.call($hWnd, "tswBGM is currently running with TSW (pID=#{$pID}).\n\nPress the hotkey(Default=F8) to toggle BGM on/off;\nPress it twice quickly or hold it to quit.", 'tswBGM', MB_ICONINFORMATION)
    $hWndText = 0
    width = 0
    wh = ' ' * 16
    while width < 600 # find the status bar, whose width is always larger than 600 (to avoid mistakenly finding other textbox window)
      $hWndText = FIND_WIN.call($hWnd, $hWndText, 'TEdit', 0)
      if $hWndText.zero?
        MESSAGE_BOX.call($hWnd, "tswBGM failed to find the status bar at the bottom of the TSW window. Please check whether this is really a TSW process?\n\n\tPID=#{$pID}, hWND=#{$hWnd}\n\nHowever, tswBGM will continue running anyway.", 'tswBGM', MB_ICONEXCLAMATION)
        break
      end
      GET_RECT.call_r($hWndText, wh)
      width = wh.unpack('L4')[2]
    end
  end
end

init

def mute() # stop playing wav sound
  asm = "\x8B\x83\x6C\x04\0\0" # mov eax, dword ptr ds:[ebx+0x46C]; TTSW10.MediaPlayer6:TMediaPlayer
  asm += [0xe8, MUTE_ADDR-QUIT_ADDR-14, 0x5b, 0xc3, 0x90].pack('clccc') # call MUTE_ADDR; pop ebx; ret
  WRITE_PROCESS.call_r($hPrc, QUIT_ADDR+3, asm, 14, $bytesRead)
  SEND_MESSAGE.call($hWnd, WM_COMMAND, QUIT_MENUID, 0) # refresh once using timer1
  WRITE_PROCESS.call_r($hPrc, QUIT_ADDR+3, QUIT_ORIG, 14, $bytesRead) # restore
end

def wait() # pause until the player clicks "OK" or the current event is over
  while sleep(TIMER_INTERVAL)
    READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2]+2, $buf2, 2, $bytesRead)
    break if $buf2 == "\1\0"
  end
end

def wait_b() # pause until the player clicks a button
  5.times do # wait for 1s at most for the button to show
    GET_CLS.call(GET_FOC.call, $buf16, 16)
    break if $buf16[0, 7] == 'TButton'
    sleep(TIMER_INTERVAL)
  end
  loop do # check is the button disappears
    GET_CLS.call(GET_FOC.call, $buf16, 16)
    break if $buf16[0, 7] != 'TButton'
    sleep(TIMER_INTERVAL)
  end
end

def routine(floor) # routine music (non-event)
  case floor
  when 0 then f = FILES[0]; t = 'on 0F. '
  when 50 then f = FILES[6]; t = 'on 50F. '
  when 44 then f = FILES[-1]; t = 'on 44F. '
  else b = (floor-1)/10+1; f = FILES[b]; t = "in Block #{b}. "
  end
  log(Time.now.strftime('[%H:%M:%S]')+' You are currently '+t) unless f == $audio
  return f
end

def isDead() # hp<0
  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[3], $buf4, 4, $bytesRead)
  if $buf4 == "\0\0\0\0"
    if $audio != FILES[16]
      fade
      log(Time.now.strftime('[%H:%M:%S]')+' You died in the tower! ')
      $audio = FILES[16]
      play
    end
    return true
  else return false
  end
end

def checkSpecial() # special event
  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[4], $buf4, 4, $bytesRead)
  offset = $buf4.unpack('L')[0]*6
  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[5]+offset, $buf4, 4, $bytesRead)
  return $buf4.unpack('S2')
rescue # not necessarily *6, so in that case *6 may lead to int32 overflow
  return [0, 0]
end

def checkHotkey() # if pressed hotkey
  msg = ' '*44
  PEEK_MESSAGE.call(msg, 0, 0, 0, 1)
  # 32 bit? 64 bit? 0x312 = hotkey event
  if msg[4, 4] == "\x12\x03\0\0" or msg[8, 4] == "\x12\x03\0\0" # if pressed hotkey
    sleep(QUIT_INTERVAL)
    msg = ' '*44
    PEEK_MESSAGE.call(msg, 0, 0, 0, 1)
    if msg[4, 4] == "\x12\x03\0\0" or msg[8, 4] == "\x12\x03\0\0" # if twice within 0.5s
      UNREG_HOTKEY.call(0, 0)
      Win32API.new('kernel32', 'CloseHandle', 'l', 'l').call($hPrc)
      fade
      $hWnd = 0 if IS_WIN.call($hWnd).zero?
      SEND_MESSAGE.call($hWndText, WM_SETTEXT, 0, '')
      MESSAGE_BOX.call($hWnd, "tswBGM has stopped.", 'tswBGM', MB_ICONINFORMATION)
      exit
    else
      $BGM = !$BGM
      SEND_MESSAGE.call($hWndText, WM_SETTEXT, 0, 'tswBGM: You turned BGM '+($BGM ? 'on.':'off.'))
      if $BGM
        $firstCheck = true # we still need to run the first check since we do not know the progress since BGM is turned off
      else
        fade
        log(Time.now.strftime('[%H:%M:%S]')+" You turned off BGM.\n\n")
        SET_CON.call("tswBGM [pID=#{$pID}] - OFF")
      end
    end
  end
end

def firstCheck(floor)
  WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead)
  case floor
  when 10
    pair = [[0, 4, 0xe], [1, 3, 0xfe]] # skeleton c, fairy
    # in each array, [check which TYPES_ADDR?, check which TYPES?, go to which progress?]
  when 20
    pair = [[2, 0, 0x14], [3, 3, 0xfe]] # game, fairy
  when 25
    pair = [[5, 0, 0x17], [6, 3, 0xfe]] # gate, fairy
  when 40
    pair = [[7, 0, 0x23], [8, 3, 0xfe]] # gate, fairy
  when 49
    pair = [[9, -1, 0x2e], [10, 3, 0xfe]] # zeno, fairy
  else
    $firstCheck = false; return 0
  end
  for i in pair
    READ_PROCESS.call_r($hPrc, BASE_ADDRESS+TYPES_ADDR[i[0]], $buf2, 2, $bytesRead)
    ($firstCheck = false; return i[2]) if $buf2.unpack('C')[0] == TYPES[i[1]]
  end
  $firstCheck = false; return 0
end

while sleep(TIMER_INTERVAL)
  checkHotkey
  next unless $BGM

  if IS_WIN.call($hWnd).zero?
    log(Time.now.strftime('[%H:%M:%S]')+" TSW (pID=#{$pID}) has been closed.\n\n")
    $pID = $tID = 0
    fade; init
  end
  audio = ''

  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], $buf2, 2, $bytesRead)
  progress = $buf2.unpack('S')[0]
  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[1], $buf2, 2, $bytesRead)
  if $buf2 == "\1\0" # using orb of flying
# The original design of TSW is to stop the current music whenever orbOfFly is used
# but I decide that it is better if we stop the music only when a) it is a special event
# or b) you fly out of the current block
    next if isDead() # the flag will also be on when dead
    if progress == 255 # cancel any event when using orbOfFly
      fade
      log(Time.now.strftime('[%H:%M:%S]')+" You are using the Orb of Flying.\n")
      WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead) # cancel flag
      next
    end
    $waitBattle = false # the battle must have ended
    while sleep(TIMER_INTERVAL) # wait for end of use
      break if isDead()
      READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[1], $buf2, 2, $bytesRead)
      READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[0], $buf4, 4, $bytesRead)
      curFloor = $buf4.unpack('l')[0]
      if (curFloor == 50 and $floor != 50) or ($floor == 50 and curFloor != 50) or ($floor == 44 and curFloor != 44) or (curFloor-1)/10 != ($floor-1)/10 # fly out of that block
        log(Time.now.strftime('[%H:%M:%S]')+" You are using the Orb of Flying.\n") unless $audio.empty?
        fade
      end
      break if $buf2 == "\0\0"
      checkHotkey
    end
    next
  end

  READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[0], $buf4, 4, $bytesRead)
  floor = $buf4.unpack('l')[0]
  progress = firstCheck(floor) if $firstCheck

  if $gateOfST # if passed gateOfSpaceAndTime
    READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[6], $buf4, 4, $bytesRead) # the hero's current coordinate
    if $buf4 == "\5\0\0\0" && floor >= 24 # you are ascending in the tower through GST
      if progress == 50 # thief becomes zeno
        log(Time.now.strftime('[%H:%M:%S]')+" Zeno shows up!\n")
        wait_b; mute
        $gateOfST = false
      else next end
    else
      $gateOfST = false
    end
  elsif floor == 24 # have not passed GST yet, on 24F
    if $audio != FILES[3]
      WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead) # cancel flag
      fade
      log(Time.now.strftime('[%H:%M:%S]')+' You are currently in Block 3. ')
      $audio = FILES[3]
      play
    end
    READ_PROCESS.call_r($hPrc, BASE_ADDRESS+TYPES_ADDR[4], $buf2, 2, $bytesRead) # the event type @ F=24 x=5 y=0
    if $buf2.unpack('C')[0] == TYPES[2] # ...is a trigger rather than floor
      loop do # wait for you to pass GST
        checkHotkey
        break unless $BGM # if turned off BGM, then no need to worry any more
        READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[6], $buf4, 4, $bytesRead) # the hero's current coordinate
        if $buf4 == "\5\0\0\0" # x=5 y=0
          $gateOfST = true
          log(Time.now.strftime('[%H:%M:%S]')+" You entered the gate of space and time!\n")
          fade; break
        end
        READ_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[0], $buf4, 4, $bytesRead)
        break if $buf4.unpack('l')[0] != 24 # you load a data or fly somewhere else
        sleep(TIMER_INTERVAL)
      end
      next
    end
  end
  c = checkSpecial
  if (c == [6, TYPES[-1]] && (floor == 3 || floor == 42 || floor == 49)) || (c[0] == 27 && floor == 49) # zeno on 3f/42f/49f
    log(Time.now.strftime('[%H:%M:%S]')+" Zeno shows up!\n") unless $audio.empty?
    WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\xFF\0", 2, $bytesRead) # flag: special event triggered
    fade; next
  elsif c == [2, 0] && floor == 50 # you touches zeno on 50f
    log(Time.now.strftime('[%H:%M:%S]')+" The tower falls down!\n") unless $audio.empty?
    fade; $epilogue = true; next
  end
  if $waitBattle # currently battling with zeno or greatMagicMaster
    if floor == $floor
      offset = TYPES_ADDR[floor == 25 ? 5 : 9] # the event type @ F=25 x=5 y=9 or F=49 x=5 y=2
      READ_PROCESS.call_r($hPrc, BASE_ADDRESS+offset, $buf2, 2, $bytesRead)
      if $buf2.unpack('C')[0] == TYPES[1] # the gate has opened
        $waitBattle = false; progress = 0xfe # fairy
      else next
      end
    else # the battle must have ended if floor # is different
      $waitBattle = false
    end
  end
  if $epilogue # you touches zeno on 50f
    if floor != 50 # you load a data
      $epilogue = false; fade
    elsif c == [5,0]
      $epilogue = false; progress = 0xfd # see you again
    else
      next
    end
  end
  if floor == 20 # check if vampire has showed up
    READ_PROCESS.call_r($hPrc, BASE_ADDRESS+TYPES_ADDR[2], $buf2, 2, $bytesRead)
    if $buf2.unpack('C')[0] == TYPES[0] # the gate has been triggered
      (fade; log(Time.now.strftime('[%H:%M:%S]')+' You will challenge Vampire! ')) if $audio != FILES[8]
      progress = 0x14 # vampire
    end
  end
  if progress == 255 # special event triggered
    next if floor == $floor
    WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead) # cancel flag if floor # has changed
    audio = routine(floor)
  else
    WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\xFF\0", 2, $bytesRead) # flag: special event triggered
    case progress
    when 0xFE # fairy after Zeno or GreatMagicMaster is beaten
      log(Time.now.strftime('[%H:%M:%S]')+' You beat the boss! ')
      audio = FILES[14]
    when 0xFD # see you again
      log(Time.now.strftime('[%H:%M:%S]')+' See you again! ')
      audio = FILES[13]
    when 0xA, 0x29, 0x2A, 0x2B # Zeno
      log(Time.now.strftime('[%H:%M:%S]')+" Zeno shows up!\n") unless $audio.empty?
      fade
    when 0x2C # I am waiting for you (on 42F)
      log(Time.now.strftime('[%H:%M:%S]')+" Zeno shows up!\n") unless $audio.empty?
      fade
      wait; mute
      WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead)
      audio = routine(floor)
    when 0xB # Zeno on 3F
      log(Time.now.strftime('[%H:%M:%S]')+" Zeno shows up!\n") unless $audio.empty?
      fade; wait_b
      30.times do # wait for 6 secs at most
        break if checkSpecial == [1, 0]
        sleep(TIMER_INTERVAL)
      end
      log(Time.now.strftime('[%H:%M:%S]')+' Prologue starts! ')
      audio = FILES[12]
    when 0xD, 0xE# skeleton army
# There should be a pause according to the original design of TSW, but I deside that the effect is better without `wait`
      log(Time.now.strftime('[%H:%M:%S]')+' You will challenge the skeleton army! ') unless $audio == FILES[7]
      (fade; wait_b) if progress == 0xD
      audio = FILES[7]
    when 0xF, 0x15, 0x27 # you beat skeleton / vampire / knight
      log(Time.now.strftime('[%H:%M:%S]')+' You beat the boss! ')
      fade; wait_b
      audio = FILES[14]
    when 0x10, 0x16, 0x18, 0x28, 0x2F # fairy
      if $audio != FILES[14]
        log(Time.now.strftime('[%H:%M:%S]')+' You see a fairy! ')
        fade
        $audio = FILES[14]
        play
      end
      wait; fade; WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead)
      audio = routine(floor)
    when 0x14 # vampire
      if $audio != FILES[8]
        log(Time.now.strftime('[%H:%M:%S]')+' You will challenge Vampire! ') unless $audio.empty?
        fade; wait; mute
      end
      audio = FILES[8]
    when 0x17 # GMM
      log(Time.now.strftime('[%H:%M:%S]')+' You will challenge Great Magic Master! ')
      fade; wait
      audio = FILES[9]
      $waitBattle = true
    when 0x19, 0x1a # princess
      log(Time.now.strftime('[%H:%M:%S]')+' You see a princess! ') unless $audio == FILES[15]
      audio = FILES[15]
    when 0x22..0x26 # knight army
      log(Time.now.strftime('[%H:%M:%S]')+' You will challenge the knight army! ') unless $audio == FILES[10]
      (fade; wait_b) if progress == 0x22
      audio = FILES[10]
    when 0x2D, 0x2E # zeno
      log(Time.now.strftime('[%H:%M:%S]')+' You will challenge Magic Seargent, Zeno! ') unless $audio == FILES[11]
      (fade; wait_b) if progress == 0x2D
      audio = FILES[11]
      $waitBattle = true
    else
      WRITE_PROCESS.call_r($hPrc, BASE_ADDRESS+OFFSETS[2], "\0\0", 2, $bytesRead)
      audio = routine(floor)
    end
  end
  $floor = floor
  next if audio == $audio
  fade
  $audio = audio
  play
end
