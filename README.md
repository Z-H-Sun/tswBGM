# tswBGM
Tower of the Sorcerer for Windows Background Music / 魔塔英文原版背景音乐
* In TSW, the BGM function is very user-hostile, which is probably why it is disabled by default. For example, / 在原版魔塔中，背景音乐 (BGM) 功能非常的用户不友好，这可能是其默认设为关闭状态的原因。例如：
  * The BGM will stop and replay from the beginning whenever you arrive at a new floor. A more reasonable design is to play the BGM continuously until the BGM changes. / 每当来到一个新的楼层都会停止 BGM 然后从头播放。但此处显然连续播放 BGM（除非 BGM 变了）会更为合理。
  * The game process will freeze whenever the BGM ends and/or starts, e.g. at certain events that require map refreshing (like going up/downstairs / using the orb of flying / warp staff / wing to fly up/down). / 每当 BGM 播放结束和开始时（例如需要刷新地图的事件：上下楼、使用飞行权杖、瞬移之翼、升华之翼、降临之翼）游戏进程都会卡住。
* To better the gaming experience, tswBGM is developed to replace the built-in BGM function. In addition, in tswBGM, the original MIDI BGMs were played and recorded using [Timidity++](http://timidity.sourceforge.net/) and [OmegaGMGS2 sound font](http://www.mediafire.com/file/2as606szvw1pbw8/OmegaGMGS2.sf2/file), which makes the music sound more catchy than the Windows built-in MIDI timbre. / 为提升游戏体验，tswBGM 旨在替代游戏自带的 BGM 功能。此外，tswBGM 中使用了 [Timidity++](http://timidity.sourceforge.net/) and [OmegaGMGS2 音色字体](http://www.mediafire.com/file/2as606szvw1pbw8/OmegaGMGS2.sf2/file) 重新录制了原有的 MIDI 音乐，使其听上去比 Windows 自带的 MIDI 音色更带感。

See Also / 另请参见: [tswKai（改）](https://github.com/Z-H-Sun/tswKai); [tswMovePoint（座標移動）](https://github.com/Z-H-Sun/tswMP); [tswSL（快捷存档）](https://github.com/Z-H-Sun/tswSL)

## Scope of application / 适用范围
* This mod can only be applied to TSW English Ver 1.2. You can download its installer <ins>[here](https://ftp.vector.co.jp/14/65/3171/tsw12.exe)</ins> or visit [the official website](http://hp.vector.co.jp/authors/VA013374/game/egame0.html). You will have to run the executable **as administrator** to install. / 本修改器仅适用于英文原版魔塔V1.2，可于<ins>[此处](https://ftp.vector.co.jp/14/65/3171/tsw12.exe)</ins>下载其安装包，或[点此](http://hp.vector.co.jp/authors/VA013374/game/egame0.html)访问官网。必须右键**以管理员权限运行**才可成功安装。
* In addition, it is recommended to install <ins>[this patch archive file](https://github.com/Z-H-Sun/tswKai/raw/main/tsw.patch.zip)</ins> to improve game experience. For more information, please refer to [tswKai](https://github.com/Z-H-Sun/tswKai#game-experience-improvement--%E6%8F%90%E5%8D%87%E6%B8%B8%E6%88%8F%E4%BD%93%E9%AA%8C). / 此外，为提升游戏体验，推荐安装<ins>[此补丁压缩包](https://github.com/Z-H-Sun/tswKai/raw/main/tsw.patch.zip)</ins>（包括汉化版），详情请见 [tswKai](https://github.com/Z-H-Sun/tswKai#game-experience-improvement--%E6%8F%90%E5%8D%87%E6%B8%B8%E6%88%8F%E4%BD%93%E9%AA%8C)。

## Usage / 使用方法
* Download <ins>[the archive of BGMs](/BGM.zip?raw=true)</ins> here, and then extract it to any path `/foo/bar`, and then you will have a folder named `/foo/bar/BGM` with all MP3 files in it. / 在此处下载 <ins>[所有 BGM 的压缩包](/BGM.zip?raw=true)</ins>，然后解压至任意路径 `/任意/目录`，此时你将有一个含有所有 MP3 背景音乐文件的文件夹，名为 `/任意/目录/BGM`。
* Download <ins>[tswBGM](https://github.com/Z-H-Sun/tswBGM/releases/latest/download/tswBGM.exe)</ins> here, and place the executable to the same folder above, `/foo/bar`. / 在此处下载 <ins>[tswBGM](https://github.com/Z-H-Sun/tswBGM/releases/latest/download/tswBGM.exe)</ins>，并将此可执行文件置于上面的 `/任意/目录` 目录下。
* Open tswBGM and TSW, whichever first. / 打开魔塔和 tswBGM，无论先后均可。
  * If TSW is opened first, you will see a message box immediately you start tswBGM. Press OK to continue, and you will hear BGM. / 如果是魔塔先开，那么在启动 tswBGM 后立即就会弹出提示框，点击确定继续后便可听到 BGM。
  * If tswBGM is opened first, nothing happens until you open TSW. Remember in tswBGM, no error prompt means everthing is working properly. / 如果是 tswBGM 先开，那么表面上看什么都没有发生，直至魔塔启动。在 tswBGM 中，只要没有错误弹窗就意味着万事 OK。
* Make sure you keep the TSW's built-in BGM off. It is off by default; if it is on, you can turn it off by navigating to the `Options` menu, uncheck `Background Music On`, and then click `Save Option`. / 确保魔塔自带的 BGM 处于关闭状态（默认为关；如果开着可到`选项`菜单取消勾选`开启背景音乐`并点`保存选项`）。
* You can run tswBGM from a terminal (e.g. `CMD`) to show the event log (I recommend using `start /w </path/to>tswBGM.exe`). Below is an example: / 可以从终端（如 `CMD`）中运行 tswBGM 以显示事件日志（推荐使用 `start /w </path/to>tswBGM.exe` 命令），以下为示例：
  ```
  [23:49:14] Waiting for TSW to load...
  [23:49:20] Loading the game... Now playing: `LuckyGold.mp3'
  [23:49:29] You are currently in Block 1. Now playing: `Block1.mp3'
  [23:49:42] Zeno shows up!
  [23:49:51] Prologue starts! Now playing: `Opening.mp3'
  [23:50:02] You are currently in Block 1. Now playing: `Block1.mp3'
  [23:50:22] You will challenge the skeleton army! Now playing: `AgainstSkeletonArmy.mp3'
  [23:50:46] You beat the boss! Now playing: `Fairy.mp3'
  [23:50:58] You are currently in Block 1. Now playing: `Block1.mp3'
  [23:51:02] You are currently in Block 2. Now playing: `Block2.mp3'
  [23:51:13] You will challenge Vampire! Now playing: `AgainstVampire.mp3'
  [23:51:20] You beat the boss! Now playing: `Fairy.mp3'
  [23:51:26] You are currently in Block 3. Now playing: `Block3.mp3'
  [23:51:31] You are using the Orb of Flying.
  [23:51:33] You are currently in Block 4. Now playing: `Block4.mp3'
  [23:51:55] You will challenge the knight army! Now playing: `AgainstKnightArmy.mp3'
  [23:52:17] You beat the boss! Now playing: `Fairy.mp3'
  [23:52:25] You are currently in Block 5. Now playing: `Block5.mp3'
  [23:52:29] Zeno shows up!
  [23:52:37] You are currently in Block 5. Now playing: `Block5.mp3'
  [23:52:53] You are using the Orb of Flying.
  [23:52:56] You are currently in Block 1. Now playing: `Block1.mp3'
  [23:52:58] You are currently on 0F. Now playing: `LuckyGold.mp3'
  [23:53:04] You are using the Orb of Flying.
  [23:53:14] You are currently in Block 5. Now playing: `Block5.mp3'
  [23:53:17] Zeno shows up!
  [23:53:19] You will challenge Magic Seargent, Zeno! Now playing: `AgainstZeno.mp3'
  [23:53:38] You beat the boss! Now playing: `Fairy.mp3'
  [23:53:52] You are using the Orb of Flying.
  [23:53:57] You are currently in Block 3. Now playing: `Block3.mp3'
  [23:53:59] You will challenge Great Magic Master! Now playing: `AgainstGreatMagicMaster.mp3'
  [23:54:06] You beat the boss! Now playing: `Fairy.mp3'
  [23:54:11] You are currently in Block 3. Now playing: `Block3.mp3'
  [23:54:18] You see a princess! Now playing: `Princess.mp3'
  [23:54:29] You are currently in Block 3. Now playing: `Block3.mp3'
  [23:54:37] You entered the gate of space and time!
  [23:54:45] Zeno shows up!
  [23:54:46] You are currently on 50F. Now playing: `LastBattle.mp3'
  [23:54:56] The tower falls down!
  [23:55:22] See you again! Now playing: `Ending.mp3'
  [23:55:50] You are currently in Block 1. Now playing: `Block1.mp3'
  [23:56:08] You died in the tower! Now playing: `GameOver.mp3'
  [23:56:16] TSW (pID=17016) has been closed.

  [23:56:17] Waiting for TSW to load...
  ```
* At anytime in the game: / 在游戏过程中随时：

  * Press <kbd>F8</kbd> to toggle BGM off/on, and you will see a message at TSW's status bar; / 按 <kbd>F8</kbd> 关/开 BGM，然后你将在魔塔底部状态栏看到一条对应信息；
  * Press <kbd>F8</kbd> twice quickly or hold <kbd>F8</kbd> to quit tswBGM; / 快速连按或长按 <kbd>F8</kbd> 以退出 tswBGM；

* You can have tswBGM running in the background all the time; whenever a TSW process is ended, tswBGM will hibernate and wait for a new TSW process, at which time the target of tswBGM will be automatically switched to that process. / 可在后台一直保持 tswBGM 运行：若关掉现有的 TSW 进程，tswBGM 将处于就绪状态等待下一次 TSW 进程的启动，届时 tswBGM 也会自动切换作用对象为当前 TSW 进程。
* You can customize tswBGM by creating a plain text file named `tswBGMdebug.txt` in the current folder (*[example here](/tswBGMdebug.txt)*), which will be loaded by the program. Therefore, you can change the BGM folder and/or filenames, the hotkey, BGM on/off default state, etc. / 可通过在当前目录下新建一名为 `tswBGMdebug.txt` 的纯文本文档（[参考此样例](/tswBGMdebug.txt)，其中内容将被程序所读取）来订制 tswBGM 的功能。可在其中变更 BGM 目录/文件名、快捷键、BGM 的默认开/关状态等。

## Troubleshooting / 疑难解答
* **Cannot register hotkey**: The hotkey might be currently occupied by other processes or another instance of tswBGM. Please close them to avoid confliction. / **无法注册热键**：快捷键可能已被其他程序抢占，或另一个 tswBGM 程序正在运行。尝试关闭它们以避免冲突。
* **Cannot find the TSW process or thread / Cannot open the TSW process for writing / write to the TSW process**: C'est la vie (not likely, though). You can check if the hWnd / PID of TSW you are running is indeed the one shown in the prompt. / **无法找到魔塔进程/线程/无法打开魔塔进程/将数据写入魔塔进程**：无解（但不太可能发生）。你可以检查下目前正在运行的魔塔程序的窗口句柄/进程号是否匹配提示框中的数字。
* For the above two issues, as an advanced option, you can manually assign `$hWnd`, `$pID`, `$tID`, `MODIFIER`, or `KEY` in `tswBGMdebug.txt` (see above). / 针对上述两个问题的高级解决方案：可在 `tswBGMdebug.txt` 中手动给`$hWnd`、`$pID`、`$tID`、`SAVEDAT_PATH`、`MODIFIER`、`KEY`赋值（见上）。
* **Cannot find the status bar**: It means just that, and thus tswBGM cannot show tip texts there. However, it will not affect the normal operation. / **无法找到状态栏**：如字面意思所言。因此 tswBGM 将无法在状态栏显示提示文本，但并不影响正常使用。
