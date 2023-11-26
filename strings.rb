# encoding: ASCII-8Bit
# CHN strings encoding is UTF-8

require './stringsGBK'

$isCHN = false
$str = Str::StrEN
module Str
  TTSW10_TITLE_STR_ADDR = 0x88E74 + BASE_ADDRESS
  APP_VERSION = '1.2'
  @strlen = 0
  module StrEN
    STRINGS = [
'','','','','','','','','','','', # 10
'tswBGM is running.

Press F8       	= Toggle on/off the enhancement of BGM;
Hold F8        	= Quit tswBGM.',
'',
'tswBGM has stopped.',
'','','','','','',

'-- tswBGM --  
Waiting for   
TSW to start ', # 20
'Do you want to stop waiting for the TSW game to start?

Choose "Yes" to quit this app; "Cancel" to do nothing;
"No" to continue waiting but hide this status window,
and you can press F8 to show it again later.',

'', 'The path for the mp3 BGM files is %s.
The BGM enhancement function will be turned off.', '',
'too short (< 2 bytes)', # 25
'too long (> 240 bytes)',
'invalid',

'Inf', # -2
'.' # -1
    ]
  end

  module StrCN
    STRINGS = [
'','','','','','','','','','','', # 10
'tswBGM（背景音乐）已开启。

单击 F8     	＝开／关游戏背景音乐的增强处理；
长按 F8     	＝退出本程序。',
'',
'tswBGM（背景音乐）已退出。',
'','','','','','',

'-- tswBGM --  
正在等待魔塔
主进程启动…', # 20
'是否停止等待魔塔主程序 TSW 启动？

按“是”将退出本程序；按“取消”则继续待机；
按“否”也将继续等待，但会隐藏此状态窗口，
之后可按 F8 快捷键重新显示。',

'', '当前 MP3 背景音乐路径%s。
如果继续，则只能暂停背景音乐增强功能。','',
'过短（< 2 字节）', # 25
'过长（> 240 字节）',
'无效或不存在',

'∞', # -2
'。' # -1
    ]
  end

  module_function
  def utf8toWChar(string)
    arr = string.unpack('U*')
    @strlen = arr.size
    arr.push 0 # end by \0\0
    return arr.pack('S*')
  end
  def strlen() # last length
    @strlen
  end
  def isCHN()
    if $isCHN == 1 # always use Chinese
      $str = Str::StrCN; return true
    elsif $isCHN == nil # always use English
      $str = Str::StrEN; return false
    end
    ReadProcessMemory.call_r($hPrc, TTSW10_TITLE_STR_ADDR, $buf, 32, 0)
    title = $buf[0, 32]
    if title.include?(APP_VERSION)
      if title.include?(StrEN::APP_NAME)
        $str = Str::StrEN
        return ($isCHN = false)
      elsif title.include?(StrCN::APP_NAME)
        $str = Str::StrCN
        return ($isCHN = true)
      end
    end
    raise_r('This is not a compatible TSW game: '+title.rstrip)
  end
end
