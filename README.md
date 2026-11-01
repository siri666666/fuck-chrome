# fuck-chrome

Chrome 会在你**不知情的情况下**往硬盘里塞一个约 **4 GB** 的本地大模型（Gemini Nano）。这个仓库教你检查它、删掉它，并且让 Chrome 以后不再下载。

> English summary at the [bottom](#english).

## 怎么回事

只要 Chrome 判断你的电脑“够格”（主要看显卡和显存），就会通过组件更新**自动下载** Gemini Nano。下载前没有任何提示，也没有设置项让你选。模型放在用户数据目录的 `OptGuideOnDeviceModel` 文件夹里。

实测机器（Windows 10，Chrome 156.0.8078.79）的情况：

| 项目 | 值 |
|---|---|
| 目录 | `%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\2025.8.8.1141\` |
| 主文件 | `weights.bin`，4,269,932,544 字节（约 4.0 GB） |
| 下载方式 | 静默下载，持续约 10 小时，全程没有提示 |

它主要用于 Chrome 的一些 AI 功能（比如“帮我写”），以及给网页调用的 Prompt API 等内置 AI 接口。

**说清楚一点**：在实测机器上没找到它在后台运行的证据。没有常驻的推理进程，Chrome 自己记录的各功能使用情况也是空的。它的问题在于**不经同意就占用 4 GB 空间和下载流量**，而且只删文件是删不掉的，Chrome 会再下回来。

## 为什么不能直接删文件夹

只删 `OptGuideOnDeviceModel` 的话，Chrome 的组件更新器会把它**重新下载**回来。正确做法分两步：

1. 用 Chrome 官方的企业策略 [`GenAILocalFoundationalModelSettings`](https://chromeenterprise.google/policies/#GenAILocalFoundationalModelSettings) 设成 `1`（不下载），禁止它下载；
2. 再删掉现有的模型文件。

按官方说法，设了策略后 Chrome 会自己删除模型。但实测重启 Chrome 后文件**原封不动**，所以第 2 步还是要自己做。

## Windows

### 一键处理

下载本仓库（Code → Download ZIP），解压后**双击 `windows\disable.cmd`**，在弹出的 UAC 窗口点“是”。

或者在 PowerShell 里运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\disable.ps1
```

脚本会做这些事：

- 在 `HKLM\SOFTWARE\Policies\Google\Chrome` 写入 `GenAILocalFoundationalModelSettings = 1`。会弹一次 UAC，只用于写这一个值。
- 删除 Chrome 正式版、Beta、Dev、Canary 以及 Chromium 的 `OptGuideOnDeviceModel` 文件夹，并显示释放了多少空间。
- 加 `-KeepFiles` 参数则只写策略，不删文件。

删除时如果提示文件被占用，就彻底退出 Chrome（包括托盘图标）后再运行一次。

### 只检查，不改动

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\check.ps1
```

会列出：策略有没有设、模型在不在（大小、版本、下载时间）、Chrome 记录的模型使用情况、有没有改过相关的实验 flag、有没有模型进程在运行。

### 手动操作

以**管理员身份**打开命令提示符：

```bat
reg add HKLM\SOFTWARE\Policies\Google\Chrome /v GenAILocalFoundationalModelSettings /t REG_DWORD /d 1 /f
```

然后删除文件夹：

```bat
rmdir /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel"
```

> 为什么写 HKLM 而不是 HKCU：`HKCU\SOFTWARE\Policies` 默认普通用户没有写权限，不提权照样会被拒绝。Chrome 两处都认，HKLM 是标准位置。

### 恢复

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\windows\undo.ps1
```

或者手动执行：`reg delete HKLM\SOFTWARE\Policies\Google\Chrome /v GenAILocalFoundationalModelSettings /f`，然后重启 Chrome。之后 Chrome 会按原来的逻辑重新下载模型。

## macOS

```bash
bash macos/disable.sh
```

等价的手动操作：

```bash
defaults write com.google.Chrome GenAILocalFoundationalModelSettings -int 1
rm -rf "$HOME/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel"
```

完全退出 Chrome（Cmd+Q）再打开，然后到 `chrome://policy` 确认。如果那里看不到这条策略，说明你的 Chrome 不读用户级 `defaults`，需要改用配置描述文件（.mobileconfig）下发，详见 [Chrome Enterprise 文档](https://support.google.com/chrome/a/answer/9020077)。

恢复：`bash macos/undo.sh`

## Linux

用普通用户身份运行，脚本只在写策略文件时调用 sudo：

```bash
bash linux/disable.sh
```

等价的手动操作：

```bash
sudo mkdir -p /etc/opt/chrome/policies/managed
echo '{ "GenAILocalFoundationalModelSettings": 1 }' | sudo tee /etc/opt/chrome/policies/managed/disable-on-device-model.json
rm -rf ~/.config/google-chrome/OptGuideOnDeviceModel
```

Chromium 的策略目录是 `/etc/chromium/policies/managed`（部分发行版是 `/etc/chromium-browser/...`），模型在 `~/.config/chromium/OptGuideOnDeviceModel`。

恢复：`bash linux/undo.sh`

## 验证

1. 重启 Chrome（地址栏输入 `chrome://restart`）。
2. 打开 `chrome://policy`，确认 `GenAILocalFoundationalModelSettings` 的值是 `1`，状态“正常”。
3. 过一两天再看一眼 `OptGuideOnDeviceModel` 有没有回来。组件更新每隔几小时跑一次，不会马上体现。
4. 想看模型状态和事件日志，可以打开 `chrome://on-device-internals`。

## 常见问题

**Chrome 显示“由你的组织管理”？**
正常现象。只要设了任意一条策略就会显示，意思是“有策略在生效”，不代表被别人控制了。

**同目录下还有个 `OptGuideOnDeviceClassifierModel`（一百多 MB），要删吗？**
那是另一个小的分类模型，不归这条策略管，本仓库不碰它。

**我在 `chrome://flags` 里开过 Prompt API 之类的选项？**
开了的话网页可以调用本地模型。模型删掉、策略生效后这些 flag 就没有作用了，可以改回 Default，保持干净。

**Gemini in Chrome（侧边栏的 Gemini）也会被关掉吗？**
不会。那个走的是云端，跟本地模型是两回事，需要在 Chrome 设置里单独关闭。

**Edge 呢？**
本仓库只覆盖 Chrome 和 Chromium。

## 测试情况

- Windows 10 + Chrome 156：完整实测过（写策略、删除、重启验证）。
- macOS / Linux：脚本按 Chrome 官方的策略机制编写，**没有在真机上测过**，欢迎提 issue 或 PR。

## 免责声明

脚本只修改上面列出的策略项，只删除 `OptGuideOnDeviceModel` 文件夹。运行前可以先读一遍源码，都很短。

---

## English

Chrome silently downloads a ~4 GB on-device LLM (Gemini Nano) into `OptGuideOnDeviceModel` in its user data folder when it thinks your hardware is capable. Deleting the folder alone does not help, because Chrome downloads it again.

The fix:

1. Set the enterprise policy `GenAILocalFoundationalModelSettings = 1` to block the download.
2. Delete the existing `OptGuideOnDeviceModel` folder. In testing, Chrome did not remove it by itself even after a restart.

| OS | Run |
|---|---|
| Windows | double-click `windows\disable.cmd` (one UAC prompt) — or `windows\check.ps1` to only inspect |
| macOS | `bash macos/disable.sh` |
| Linux | `bash linux/disable.sh` (as normal user, uses sudo for the policy file) |

Each folder has an `undo` script. Verify at `chrome://policy` after restarting Chrome. Tested on Windows 10 / Chrome 156. The macOS and Linux scripts have not been tested on real machines yet.

License: MIT
