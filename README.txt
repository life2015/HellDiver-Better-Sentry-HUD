炮台 HUD 优化 0.3.2 — 正式版 / Release

本版新增独立的 HUD 卡片背景不透明度设置，低于 30% 隐藏侧边竖线。
Adds independent card background opacity; the side stripe hides below 30%.

保留默认开启的“显示炮台距离”菜单开关，在 World Marker 下方居中显示整数米数。
Adds a default-on Show Sentry Distance toggle, with centered metre labels below world markers.

World Marker 开火提示改为图标右下角的绿色圆点，弹药条保持常亮。
World markers now show a green dot at the icon's bottom-right while firing;
the pale-yellow ammo bar stays steady. The dot follows World Marker Opacity.
保留中英文菜单、右侧居中布局与独立不透明度设置。绿色圆点的游戏内效果待确认。
Chinese/English menus, centered right-side cards and independent opacity settings are retained.
The new firing indicator still needs in-game visual confirmation.

在左下角玩家状态栏右侧，显示自己召唤的自动哨戒炮的血量、弹药、剩余部署时间和开火状态。
独立项目，不覆盖 Enemy HP HUD+；不包含手操固定炮位。

新增设置菜单 / In-game settings
- 安装 Mod Options Menu v1.2 和 BSL v18 或更新版本后，在 ESC > MODS > SENTRY HUD 设置。
  菜单为可选依赖；未安装时仍使用 sentry_hud.cfg，基础 HUD 保留 BSL v15 / API 1 兼容。
  https://www.nexusmods.com/helldivers2/mods/16625
  https://github.com/CowboyBingus/ModOptionsMenu
- HUD Layout 提供 Beside Player Status（原布局）、Screen Right（屏幕右侧）和 Manual Position。
  默认保留原布局。Screen Right 整组卡片在屏幕右侧垂直居中，竖直颜色条位于卡片右边；
  图标、文字和底部血条保持正常阅读方向。右侧布局不依赖 Player Status 是否可见。
- 可调 Show Sentry HUD、HUD Scale、Maximum Sentries、Player Status Gap、
  Right Edge Margin、Right Layout Vertical Offset 和 Manual X / Y。
  另有 Sentry World Markers、World Marker Scale 和 World Marker Range，共 16 项。
- Sentry HUD Opacity (%) 默认 100%，统一调整卡片图标、文字、状态条及背景。
  World Marker Opacity (%) 默认 60%，统一调整位置图标、开火圆点、生命／弹药条及距离文字。
  两项范围均为 0–100%，步进 5%；0% 只隐藏对应部分。100% 保留原设计中背景和线条的透明层次。
  Both opacity sliders range from 0–100% in 5% steps and are saved independently.
  Card opacity defaults to 100%; world marker opacity defaults to 60%. APPLY changes immediately.
- HUD Card Background Opacity (%) / HUD 卡片背景不透明度 (%) 范围 0–100%，步进 1%。
  默认 100% 保留原有半透明底色；0% 完全透明。低于 30% 隐藏侧边竖线，30% 及以上保留。
  仅调整卡片背景，不改变文字、图标、血条或 World Marker；整体 HUD 不透明度仍作用于卡片。
  左侧、右侧和手动布局均适用，切换数值立即更新，设置会保存。
  Background opacity defaults to 100% of the original shading. Below 30% the side stripe disappears.
  Text, icons, bars and world markers are unaffected; overall HUD opacity still applies.
- 点击 APPLY 后生效，关闭菜单即可看到布局变化，无须重启游戏。
  Mod Options Menu 保存设置，下次启动恢复；首次注册以现有 cfg 值作为默认值。
  有菜单保存值时优先使用保存值，不改写 cfg。未应用的菜单编辑不影响 HUD。
- Screen Right 默认右边距 48，整组卡片（含溢出数量）垂直居中。
  Right Layout Vertical Offset 默认为 0，正数上移、负数下移；以 1920x1080 为基准缩放。
  旧版本 right_bottom 值不再用于定位，避免升级后仍停留在底部。
  打开地图或无法确认地图状态时隐藏右侧卡片，关闭地图后恢复；余弹基准保留。
  右上角任务面板已找到候选结构，但尚未实机核对可见内容下沿，未启用自动跟随。
  原布局跟随原生 HUD 缩放；右侧和手动布局使用分辨率缩放。
- 菜单分类、全部 16 项设置及说明、布局选项跟随游戏的“文字语言”：
  简体与繁体中文统一使用中文文案，其余语言使用英文；HUD 卡片文字仍为英文。
  复用 Mod Options Menu 公开的 BingusTranslations.game_language 数据，不按系统、Steam
  或翻译包强制语言判断。尚未检测到文字语言时使用英文；修改语言后重新打开 ESC 菜单刷新。
  Only the game Text Language controls our menu. Both Chinese variants use Chinese text;
  other or unknown languages use English. Reopen the escape menu after changing language.
  选项标识与保存值保持不变，不重新注册菜单。

炮台位置标记 / Sentry world markers
- 完整纯白炮台图标的中心对准炮台根节点的世界位置，类似位置标点；下方是两条细长条：上方生命、下方弹药。
  取消额外 1.2 米高度和屏幕向上偏移；改变图标大小时，图标中心仍保持在相同的投影位置。
  相机按当前玩家视角的位置和朝向匹配，排除同名的地图／预览相机；匹配失败时隐藏标记。
  投影显式使用 GUI 分辨率，前后方判断使用同一相机的世界位置与朝向，不把投影深度当成米数。
  不画面板底色，不显示名称、H 或 Ammo 等文字。图标与状态条占 40x46 逻辑像素，下方可显示距离。
  使用独立屏幕 GUI，不做遮挡检测，因此隔着地形仍显示；不修改游戏实体或原生材质。
  原生图标所有路径统一染成白色，保留原本绿色部分中的炮身与底座，不裁掉炮台形状。
  位置标记默认按原有透明度的 60% 绘制，可在菜单中调整。
  图标将各档位的覆盖率写入 RGB 与 Alpha 通道，避免仅依赖材质处理绘制透明度。
  弹药条使用与卡片 FIRING 相同的浅黄色，始终常亮。开火时图标右下角显示绿色实心圆点，
  停火后消失；圆点随标记大小缩放，并遵循 World Marker Opacity。开火判断与 HUD 卡片一致。
- 显示炮台距离 / Show Sentry Distance 默认开启，可在 Mod 菜单中独立关闭。
  在两条状态条下方居中显示，例如 42 m；随标记大小、不透明度调整，实时更新。
  使用已验证的当前玩家视角坐标到炮台的三维直线距离，四舍五入至整数米。
  第三人称镜头与角色脚下有位置差，因此显示值可能与角色脚下的距离略有差异。
  关闭开关立即移除距离文字；底部空间不足时仅隐藏文字，不移动位置图标。
  Distance is measured from the current player camera to the sentry in 3D, rounded to metres.
  The label follows marker scale and opacity. Disable Show Sentry Distance to hide it.
- 生命条按当前 HP / 最大 HP 填充。弹药条以每座炮台首次读到的正数余弹作为 100%，
  后续按当前余弹 / 初始余弹填充；零弹药显示空条。这个基准不是游戏声明的弹匣容量。
  中途启用或首次识别前已经开火时，以首次观察时的剩余弹药为基准。
  打开菜单、切换 HUD 开关或短暂读取失败不会重置基准；销毁、回收、离场或换任务后清除。
  同类型多座炮台分别记录，换弹不改变初始基准；补充到超过基准时按 100% 显示。
  精确弹药数字和备用弹匣仍在 HUD 卡片中显示。无法读取弹药或生命上限时，对应条使用虚线。
- 位置读取核对完整实体描述、unit generation、object ID、pose getter 签名与前后指针，
  读取失败就隐藏该标记；不将未知位置回退到准星。销毁／回收随原有生命期过滤移除。
- 标记每帧重新投影，默认 300m，范围 25–500m。镜头背后、屏幕外、打开地图或菜单时隐藏。
  地图状态无法读取时也隐藏位置标记。密集重叠炮台尚未增加聚合或避让。
- 菜单中的 Sentry World Markers 可单独关闭位置标记，不影响卡片；Show Sentry HUD 是总开关。
  卡片与标记大小分别调整。标记相机／绘制失败不影响卡片显示。
- 离线身份读取、屏幕投影、颜色、生命条、未知容量、设置和生命周期测试已覆盖。
  用户已确认相机与投影修复后的 World Marker 正常显示；初始余弹基准的游戏内效果待验证。

功能与验证状态
- 名称左侧显示对应的游戏原生炮台图标，覆盖机枪、加特林、自动炮、火箭、迫击炮、
  EMS、毒气、火焰、激光、特斯拉共 10 类；英文名称保留。图标读取失败时保留文字 HUD。
  ui5 改为按原始路径顺序分层着色，修复 ui4 在游戏中丢失绿色、整幅图标变白的问题。
  图标为 40 个 HUD 逻辑像素，跨名称与 HP 两行；名称和 HP 在图标右侧对齐。
  采用布局 02：底部血条向左延伸到图标下方，与图标左缘对齐。
  面板宽度为 274，给弹药和状态留出间距。
- 同时显示多座炮台：HP 数字与血条、当前弹药、备用弹匣数，以及 READY / FIRING / EMPTY。
- 默认读取原生 Player Status 武器行与健康行的实际边界，贴着其右侧显示，
  底边对齐，并随原生 HUD 缩放和位置移动。右侧留 12 个 HUD 逻辑像素。
  状态栏隐藏、边界无法读取或右侧空间不足时，隐藏炮台面板。
- 英文倒计时 TIME MM:SS 直接读取游戏当前剩余部署时间，中途识别也不会重新计时。
  到期或开始回收后直接隐藏该炮台面板，不显示回收状态；无法读到计时则显示 TIME --:--。
  已验证机枪自然到期、回收、移除，以及火箭的实时倒计时。
- 已在当前游戏只读采样，并用真实 Lua 模块回放验证机枪、加特林、火箭和自动炮。
  12 组快照包含四座炮台、弹药消耗和健康数组重排；显示顺序保持稳定。
- 使用网络对象的完整 64 位归属玩家标识，匹配本地玩家。四种炮台已匹配到用户；
  队友炮台排除有合成测试，多人客户端、主机迁移与归属转移仍待游戏内验证。
  这个字段是当前网络归属，不是不可变的召唤历史记录。
- 不使用本机模拟权限、最近玩家或炮台最后受伤的伤害来源判断归属。
- 弹药来自当前实时弹匣；若该武器有膛内弹药，额外计入一发。
  备用弹匣单独显示为 +N MAG，不用基础容量推算带舰船升级的总弹量。
- FIRING 根据相邻采样弹药减少判断，保留 0.3 秒。补弹和首次采样不会误判为开火。
  默认 125ms 采样；无法表达每次采样之间全部射击过程。
- 迫击炮、EMS、毒气、火焰、激光和特斯拉仅有类型识别，尚未完整验证。
  无法确认的弹药显示 --；激光/电弧热量和开火状态暂不支持。
- 没有自己的有效炮台、打开菜单、换世界或读取失败时隐藏 HUD。
- Lua/BSL v15 发现、归属边界、生命期及多分辨率布局测试已通过。
  ui3 的原生边界已通过当前游戏只读快照及真实 Lua 绘制回放验证。
  ui5 已通过只读取遮罩、忽略贴图颜色的材质模拟测试，核对全部 10 类图标的绿白颜色、
  路径遮挡顺序、控件复用及部分图层失败时的文字降级；颜色修复的游戏内观感待实测。

安装
1. 基础 HUD 需要 Bingus Shared Loader v15+（API 1）；游戏内设置需要 BSL v18+ 和
   Mod Options Menu v1.2。本包不含这些依赖。
2. 退出游戏和 HD2 Arsenal 后，通过 HD2 Arsenal 导入本 ZIP 并启用「炮台 HUD 优化」。
   若手动安装，需为 Addon 中三个同名文件选取空闲且一致的 patch_N 后缀，
   不可直接覆盖已被其他 mod 占用的 patch_0。
3. 启动游戏，进入任务并召唤自动哨戒炮。
4. 使用菜单调整后点击 APPLY。未安装菜单时，可把 sentry_hud.cfg.example 复制为
   %LOCALAPPDATA%\sentry_hud.cfg，修改后重启游戏。
卸载：通过管理器停用；手动安装时只删除本 mod 安装的三个文件。
日志：%LOCALAPPDATA%\SentryHUD.log。

布局
layout=1, panel_gap=12, scale=1, max_rows=6。多座炮台从下向上排列。
自动模式跟随 Player Status 的位置及原生 HUD 缩放；scale 是额外大小倍率。
旧配置中已有的 x/y 在自动模式下不生效，无需删除旧配置。
设置 layout=2 使用屏幕右侧；layout=3 使用手动坐标：x=540, y=48（1920x1080 基准，
屏幕左边和底边为原点）；此模式只随屏幕分辨率缩放。
build/layout-preview.svg 是真实 Lua 绘制调用生成的模拟预览，不是游戏截图。
旧 cfg 未指定 layout 时，anchor_player=0 仍选择手动模式；明确指定 layout 时以它为准。

构建与测试
python3 scripts/build.py
PYTHONPATH=/private/tmp/ehp-validation <带 lupa.lua51 的 Python> tests/verify.py
本项目构建无需原版 Enemy HP 包。BSL 发现测试使用旁边 BingusSharedLoader 的 v15 标签。
scripts/replay_live.py 使用本地保留的诊断快照；原始快照和模块片段不随包分发。

支持：Steam build 25480438 / 游戏 1.8.46015.0，BSL v15 / API 1。
其他游戏构建会自动停止读取，需要重新适配。
退出回调只停止采样并释放 Lua 引用，GUI 世界的最终清理由引擎负责。

图标构建：scripts/extract_icons.ps1 只读提取当前游戏图标库；scripts/build_icons.py
使用 Pillow 和 resvg-py 转换 10 个原生矢量符号并生成分层遮罩的 BC3 多级贴图。
常规 scripts/build.py 使用 assets/icons 已生成资源，不要求转换工具或 HUD+ 安装。

0.3.2 离线验证状态
背景不透明度、29%/30% 阈值、三种布局切换及保存与中英文菜单通过离线测试。
距离计算、居中、显示开关、缩放与透明度及文字清理保留回归测试。
绿色开火圆点、弹药条常亮、停火与隐藏后的清理保留回归测试。
右侧居中、上下偏移、地图隐藏及中英文菜单切换保留回归测试；新版本游戏内效果待确认。
任务面板候选位置见 research/OBJECTIVE_ANCHOR.txt；实时跟随需要实机快照确认。
