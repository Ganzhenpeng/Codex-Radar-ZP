# Codex Radar ZP

本项目是只监听 `127.0.0.1:43721` 的本地只读面板：一条证据链来自本机 Codex App Server 的 `account/rateLimits/read`，另一条来自 Codex Resets 对 `@thsottiaux` 的第三方转录/分类。两者在界面上严格分开；预测不会显示为 OpenAI 官方承诺或已重置。

## 功能

- 60×60 圆形浮窗同时显示通用周额度剩余比例和环形剩余量，悬停展开完整面板，鼠标离开 4 秒后收回。
- 内置数码蛋、四星龙珠、赛博核心、像素史莱姆、魔法星球、蒸汽齿轮、深海水滴、熔岩太阳、月光猫眼、量子黑洞、彩虹糖球和太空舱 12 套原创 CSS/WPF 主题；右键小圆球或点击 `✦` 会打开 3×4 球体缩略图选择器，选择随浮窗位置保存在本机。
- Plus 同时显示短时主额度和周额度；Pro 只返回周窗口时不虚构 5 小时额度。
- 显示自然恢复时间、七天使用速度、平衡条和本地项目用量账本。
- Tibo 信号显示发帖与预计截止的北京时间，并保留原帖链接及第三方预测标记。
- 个人额度每 5 分钟只读刷新；公共 Tracker 在允许时段每小时最多检查一次。
- 零第三方运行时依赖，不读取或上传 Codex 对话和项目文件。

## 运行

需要 Windows 10/11、Codex 桌面端和 Node.js 24 或更高版本。

```powershell
git clone https://github.com/Ganzhenpeng/Codex-Radar-ZP.git
cd Codex-Radar-ZP
npm test
```

启动本地服务和额度浮窗：

```powershell
.\scripts\start-radar-overlay.ps1
```

打开 <http://127.0.0.1:43721>。服务运行期间，个人额度每 5 分钟通过本机 App Server 做一次只读更新；Tibo 公共 Tracker 才遵守北京时间/旧金山时段限制。也可点击“立即刷新”同时执行一次个人额度与公共 Tracker 的只读检查。服务只对本机 Host 响应，不启用 CORS。

```powershell
npm test
npm run check
```

## 登录自动启动（须先完成手动验证）

下列脚本**不会自动执行**。在你确认面板、个人额度和通知均符合预期后，才手动运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-autostart.ps1
```

它优先建立当前用户登录时、低权限、隐藏窗口的 `Codex Reset Radar` 计划任务。若系统策略拒绝创建用户计划任务，脚本会改建当前用户 Startup 快捷方式。安装器会立即启动并读回验证服务与浮窗，不需要等到下次 Windows 登录。浮层仅在检测到 Codex 桌面窗口时显示；关闭 Codex 后守护进程继续等待，再次打开后恢复为小圆圈。停止服务或注销启动入口不会删除本机历史：

```powershell
.\scripts\stop-radar.ps1
.\scripts\uninstall-autostart.ps1
```

若需验证 Windows 通知，可显式运行（脚本会强制使用系统 Windows PowerShell 5.1；它不会记作真实事件）：

```powershell
.\scripts\test-toast.ps1
```

## 安全与边界

- 不保存登录凭据、令牌、邮箱或 App Server 原始响应；仅持久化展示所需的归一化额度字段、ETag、公开事件和通知去重键。
- 不会登录、兑换重置卡、购买额度、发送邮件或改动 Codex 设置。
- 遇到公共源 304、429、503、超时或 App Server 不可用时，保留最近成功缓存并标明可能过期/暂不可读，绝不会将缺失字段显示成 0%。
- Windows Toast 仅在新预测、公开公告、个人额度明显恢复、重置卡增加等关键变化出现时触发；内容会明确标注“第三方预测”“公开公告”或“个人账户确认”。
- 浮层按通用 `codex` 额度桶实际返回的窗口显示：Plus 同时返回短时窗口和七天窗口时分别标为“主额度”和“周额度”；只有周窗口时只显示“周额度”。独立模型（例如 GPT-5.3-Codex-Spark）的短时窗口不会冒充通用主额度。每条额度均显示已用、剩余和自然恢复时间；“详情”会打开本机详细网页。
- “周额度”文字本身可点击并打开 `usage.html`，“详情”打开完整雷达；浮层不再额外占用一行显示“额度总览”。用量总览只消费本机 App Server 直接提供的字段；不读取或上传线程正文，也不把未提供的绝对 token 或 eToken 伪造成数值。
- 周额度会显示“使用速度”：从本周窗口起点累计到当前时刻的实际已用比例，与同一时刻按七天均匀使用应消耗的基准比较；平衡条左侧为偏慢、中央为正好、右侧为偏快。它是节奏指标，不是 token 总量或精确耗尽预测。
- 浮层可用鼠标拖动；右上角 `x` 只隐藏本次 Codex 使用期间的浮层。运行状态、日志、PID 和窗口位置只保存在本机 `data/`，不会提交到 GitHub。

## License

MIT
