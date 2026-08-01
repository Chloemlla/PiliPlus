# PiliPlus UI/UX 不合理问题扫描报告

> 扫描日期：2026-08-01
> 扫描范围：lib/ 全模块（视频播放器、首页、我的、搜索、设置、直播、评论、动态、个人主页、关注、收藏、历史、下载、订阅、通用组件）
> 扫描方式：6 路并行 Agent 逐文件审查

---

## 总体统计

| 严重度 | 数量 |
|--------|------|
| 🔴 高 | 25+ |
| 🟡 中 | 30+ |
| 🟢 低 | 15+ |
| 系统性 | 4 类（贯穿全项目） |

---

## 目录

1. [视频播放器模块](#1-视频播放器模块)
2. [首页/我的/导航模块](#2-首页我的导航模块)
3. [搜索/设置/弹窗模块](#3-搜索设置弹窗模块)
4. [直播/评论/动态模块](#4-直播评论动态模块)
5. [个人主页/关注/收藏/历史/下载/订阅模块](#5-个人主页关注收藏历史下载订阅模块)
6. [通用组件模块](#6-通用组件模块)
7. [系统性问题（贯穿全项目）](#7-系统性问题贯穿全项目)
8. [设计良好的模块](#8-设计良好的模块)

---

## 1. 视频播放器模块

### 🔴 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.1 | `lib/pages/video/view.dart` | 653-655, 658-665, 676-696 | 返回/主页/更多设置按钮使用 `SizedBox(width: 42, height: 34)` | 高度至少改为 44 |
| 1.2 | `lib/pages/video/widgets/header_control.dart` | 1996-1998 | `btnWidth = 40, btnHeight = 34` 所有头部控制按钮小于 44 | 将 `btnHeight` 改为 44 |
| 1.3 | `lib/common/widgets/in_app_mini_player.dart` | 195, 373-383 | `_buttonSize = 32.0` 迷你播放器按钮仅 32×32 | 改为 44 |
| 1.4 | `lib/pages/video/introduction/ugc/widgets/action_item.dart` | 64-65 | 点赞/投币/收藏图标容器 `dimension: 28` | 改为 44 |
| 1.5 | `lib/common/widgets/button/icon_button.dart` | 20-23 | 通用 `iconButton` 默认 `size: 36` | 默认改为 44 |

### 🟡 缺少触摸反馈（GestureDetector 无 InkWell）

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.6 | `lib/pages/video/send_danmaku/view.dart` | 288-313 | 弹幕样式（滚动/顶部/底部）和字号选项用 GestureDetector 无涟漪 | 改用 InkWell |
| 1.7 | `lib/pages/video/send_danmaku/view.dart` | 237-285 | 弹幕颜色选择色块用 GestureDetector 无反馈 | 改用 InkWell |
| 1.8 | `lib/pages/video/pay_coins/view.dart` | 349, 367 | 投币页左右箭头用 GestureDetector | 改用 InkWell 或 IconButton |

### 🟡 对比度不足

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.9 | `lib/pages/video/introduction/ugc/widgets/action_item.dart` | 43-48 | 未选中状态使用 `colorScheme.outline`，浅色背景对比度弱 | 改用 `onSurfaceVariant` |
| 1.10 | `lib/pages/video/introduction/ugc/widgets/menu_row.dart` | 48-67 | `ActionRowLineItem` 未选中文字/图标使用 `outline` | 同上 |
| 1.11 | `lib/common/widgets/svg/play_icon.dart` | 193 | 播放按钮阴影透明度极低，深色背景不可见 | 改用 `Colors.black54` 或加白色阴影变体 |

### 🟡 布局混乱

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.12 | `lib/pages/video/pay_coins/view.dart` | 421-469 | Stack 中"同时点赞"复选框（左对齐）和关闭按钮（居中）可能重叠 | 改用 Row + spaceBetween |
| 1.13 | `lib/pages/video/view.dart` | 1149-1160 | 手动播放按钮 `right: 12, bottom: 10` 太靠边，可能被圆角裁剪 | 改为 `right: 16, bottom: 24` |
| 1.14 | `lib/pages/video/view.dart` | 1462-1614 | 视频播放器 Stack 使用 `clipBehavior: Clip.none`，手动播放按钮可能溢出视频区域 | 添加关键边界裁剪或调整定位 |

### 🔴 缺少加载/错误状态

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.15 | `lib/pages/video/view.dart` | 1467 | 视频初始化期间纯黑屏，无加载指示器 | 居中添加 CircularProgressIndicator 或模糊封面图 |
| 1.16 | `lib/pages/video/controller.dart` | 1086-1092 | `queryVideoUrl` 失败仅 toast，用户可能错过 | 在视频区域显示内联错误信息和重试按钮 |
| 1.17 | `lib/pages/video/view.dart` | 716-744 | 视频正在查询时用户点击播放，无任何视觉反馈 | 查询期间添加加载动画覆盖层 |

### 🟡 元素重叠

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.18 | `lib/pages/video/view.dart` | 1498-1517 | 跳过片段列表 `bottom: 75`，全屏时可能和底部控制栏重叠 | 动态计算底部偏移 |
| 1.19 | `lib/pages/video/view.dart` | 1088-1165 | `manualPlayerWidget` 使用 `Positioned.fill` 且无 `clipBehavior` | 添加更好的定位约束 |

### 🟢 间距不一致

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.20 | `lib/pages/video/view.dart` | 1311-1382 | 发弹幕按钮（32px 高）和弹幕开关（38px 高）在 45px 容器中垂直对齐不一致 | 统一垂直居中策略 |
| 1.21 | `lib/pages/video/bookmark/video_bookmark_sheet.dart` | 140-156 | 头部 IconButton 和 TextButton.icon 高度不同 | 统一 Row 中 CrossAxisAlignment |

### 🟡 缺少无障碍标签

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.22 | `lib/pages/video/send_danmaku/view.dart` | 288-313 | 弹幕模式/字号选项无 `semanticsLabel` | 添加语义标签 |
| 1.23 | `lib/pages/video/pay_coins/view.dart` | 349-385 | 投币箭头无 `tooltip` 或 `semanticsLabel` | 添加 `tooltip` |
| 1.24 | `lib/pages/video/send_danmaku/view.dart` | 106-133 | 颜色选择器色块无语义标签 | 添加色值或名称标签 |

### 🟢 手势区域与视觉目标不匹配

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 1.25 | `lib/pages/video/introduction/ugc/widgets/action_item.dart` | 67-88 | InkWell 通过 Expanded 撑满宽度，但视觉上仅 18px 图标，点击区域无视觉提示 | 添加 `splashFactory` 让涟漪覆盖全区域 |
| 1.26 | `lib/pages/video/widgets/header_control.dart` | 2014-2253 | 按钮 40×34 但图标仅 15-20px，视觉目标和点击区域差距大 | 确保涟漪效果清晰可见 |
| 1.27 | `lib/pages/video/view.dart` | 1088-1165 | 60px 播放图标阴影超出 IconButton 范围不可点击 | 用更大 SizedBox 包裹匹配阴影范围 |


---

## 2. 首页/我的/导航模块

### 🔴 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 2.1 | `lib/pages/home/view.dart` | 204-225 | 用户头像触摸目标仅 34×34 | 用 SizedBox 44×44 包裹并居中头像 |
| 2.2 | `lib/pages/mine/view.dart` | 140 | 头部 action 按钮使用 `shrinkWrap`，有效触摸目标 38×38 | 移除 shrinkWrap 或增加 padding |

### 🔴 图片未裁剪圆角

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 2.3 | `lib/pages/mine/widgets/item.dart` | 37-58 | `DecoratedBox` 指定 `borderRadius: 12` 但未裁剪子元素，图片显示尖角 | 用 `ClipRRect(borderRadius: 12)` 包裹 |

### 🟡 缺少加载/错误状态

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 2.4 | `lib/pages/mine/view.dart` | 88-92 | 收藏夹加载时整个隐藏，数据到达时突然出现，产生跳跃 | 保持头部可见，内容区显示 shimmer 骨架屏 |
| 2.5 | `lib/pages/mine/view.dart` | 556-564 | 收藏夹加载失败只显示错误文字，无重试按钮 | 添加"重试"按钮 |
| 2.6 | `lib/pages/home/view.dart` | 179 | 搜索框默认提示文字从空字符串开始，API 完成才显示 | 显示静态占位符如"搜索" |

### 🟢 布局问题

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 2.7 | `lib/pages/mine/widgets/item.dart` | 61, 66 | 文字前导空格做间距：`' ${item.title}'` | 改用 Padding 或 EdgeInsets |
| 2.8 | `lib/pages/mine/widgets/item.dart` | 43-47 | 阴影方向朝上 `offset: Offset(6, -8)`，违反 Material Design 惯例 | 改为 `Offset(0, 4)` 标准朝下阴影 |

### 🟢 缺少无障碍标签

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 2.9 | `lib/pages/home/view.dart` | 294 | 通知图标 `Icon(Icons.notifications_none)` 无语义标签 | 添加 `semanticLabel: '消息'` |

---

## 3. 搜索/设置/弹窗模块

### 🔴 空状态误用 HttpError

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.1 | `lib/pages/search_trending/view.dart` | 200-202 | 热搜榜为空时显示错误界面，而非"暂无热搜" | 用中性空状态替代 |
| 3.2 | `lib/pages/settings_search/view.dart` | 126 | 设置搜索无结果时显示错误界面 | 显示"无结果"提示而非错误 |

### 🔴 颜色选择器滑块过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.3 | `lib/pages/setting/slide_color_picker.dart` | 58-59 | 滑块 thumb 仅 4dp 宽 × 25dp 高，几乎无法拖动 | 改为 `Size(20, 28)` |

### 🟡 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.4 | `lib/pages/search/view.dart` | 375-401 | 搜索历史记录/导出按钮使用 `shrinkWrap` + 零填充 | 添加 `minWidth: 44, minHeight: 44` 约束 |
| 3.5 | `lib/pages/setting/widgets/switch_item.dart` | 112-114 | Switch 缩放到 80%，thumb 约 19dp | 移除 `Transform.scale` |
| 3.6 | `lib/pages/setting/widgets/slider_dialog.dart` | 43 | Slider 约束在 40dp 高度 | 至少 50dp 或使用自然高度 |

### 🟡 缺少加载状态

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.7 | `lib/pages/search/view.dart` | 136-175 | 搜索建议仅在结果非空时渲染，API 请求中无任何反馈 | 添加小型 CircularProgressIndicator 或 shimmer |
| 3.8 | `lib/pages/search/view.dart` | 275-283 | 热门/推荐区域 Loading 状态返回 `SliverToBoxAdapter()` 空白 | 显示占位骨架 |

### 🟡 缺少触摸反馈

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.9 | `lib/pages/search_result/view.dart` | 104-105 | Tab 栏覆盖 `overlayColor: Colors.transparent` + `splashFactory: NoSplash` | 使用柔和高亮色而非完全禁用 |

### 🟡 其他问题

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 3.10 | `lib/common/widgets/custom_tooltip.dart` | 82 | `HitTestBehavior.opaque` 可能阻挡子元素交互 | 改用 `translucent` |
| 3.11 | `lib/pages/search/widgets/hot_keyword.dart` | 48-49 | 整个关键字项被冗余 Tooltip 包裹，文字已可见 | 仅包裹图标部分或移除 |
| 3.12 | `lib/pages/search/widgets/search_text.dart` | 38 | InkWell 无语义标签 | 添加 `Semantics(button: true, label: ...)` |
| 3.13 | `lib/pages/settings_search/view.dart` | 95, 107 | 清除和返回按钮无 tooltip | 添加 `tooltip: '清除'` 和 `tooltip: '返回'` |
| 3.14 | `lib/pages/setting/pages/color_select.dart` | 130-133 | 动态颜色复选框 `visualDensity: -4` 过度压缩 | 使用更温和的密度值 |
| 3.15 | `lib/common/widgets/dialog/report.dart` | 69-72 | 举报表单 label 22 个中文字符过长 | 改用更短的 label 或 hintText |


---

## 4. 直播/评论/动态模块

### 🔴 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.1 | `lib/pages/live/view.dart` | 132-169 | 首帧/赛事/标签按钮 `size: 26` | 改为 38+ 或包裹 44×44 |
| 4.2 | `lib/pages/live/widgets/live_item_app.dart` | 71-78 | 直播卡片反馈按钮 29×29 | 改为 44×44 |
| 4.3 | `lib/pages/live_room/view.dart` | 862-870 | 直播间点赞按钮 `SizedBox.square(dimension: 34)` | 改为 44 |
| 4.4 | `lib/pages/live_room/view.dart` | 811-839, 906-918 | 弹幕开关/表情按钮 `SizedBox(34×34)` | 改为 44 |
| 4.5 | `lib/pages/video/reply/widgets/reply_item_grpc.dart` | 483-487 | 评论操作按钮 `shrinkWrap` + 零填充 | 设置最小高度 40 |
| 4.6 | `lib/pages/video/reply/widgets/zan_grpc.dart` | 119-177 | 赞/踩按钮 `SizedBox(height: 32)` | 改为 `minimumSize: Size(44, 44)` |
| 4.7 | `lib/pages/dynamics/widgets/author_panel.dart` | 144-155 | 动态更多按钮 32×32 | 改为 44×44 |
| 4.8 | `lib/pages/dynamics/view.dart` | 33-53 | 动态创建按钮 34×34 | 改为 44×44 |

### 🟡 缺少加载状态

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.9 | `lib/pages/live_room/widgets/chat_panel.dart` | 52-60 | 聊天列表无连接中指示 | 显示"连接中..." |
| 4.10 | `lib/pages/video/reply/view.dart` | 192-196 | "加载中..." 纯文字无 spinner | 改用 CircularProgressIndicator + 文字 |
| 4.11 | `lib/pages/video/reply_reply/view.dart` | 297-308 | 同上 | 同上 |
| 4.12 | `lib/pages/main_reply/view.dart` | 129-135 | 同上 | 同上 |

### 🟡 对比度不足

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.13 | `lib/pages/live_room/view.dart` | 843-846 | 占位文字 "发送弹幕" 使用 `baseWhite(#EEEEEE)` 在半透明背景上 | 改用 `Colors.white54` |
| 4.14 | `lib/pages/live_room/widgets/chat_panel.dart` | 41-43 | 用户名 `0.6` 透明度在半透明背景上对比度低 | 透明度至少 0.85 |

### 🟡 元素重叠/布局混乱

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.15 | `lib/pages/live/widgets/live_item_app.dart` | 71-76 | 反馈按钮 `right: -5, bottom: -2` 超出卡片边界 | 移到 `right: 4, bottom: 4` |
| 4.16 | `lib/pages/video/reply/widgets/reply_item_grpc.dart` | 509-559 | 操作按钮间距仅 2px | 至少 8px |

### 🟡 缺少触摸反馈

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.17 | `lib/pages/live/view.dart` | 107-125 | 直播分区标签无 InkWell 涟漪 | 包裹 SearchText 在 InkWell 中 |

### 🟢 其他问题

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.18 | `lib/pages/dynamics/widgets/action_panel.dart` | 30-31 | 动态操作按钮 `spaceAround` 导致间距随文字长度变化 | 改用 `spaceEvenly` |
| 4.19 | `lib/pages/live_room/view.dart` | 797-846 | 输入区域看起来像可编辑输入框，实际是点击弹窗 | 明确提示"点击发送消息" |
| 4.20 | `lib/pages/live_room/view.dart` | 807-840 | 弹幕开关无状态颜色指示 | 激活时添加背景高亮 |
| 4.21 | `lib/pages/dynamics_detail/view.dart` | 303-353 | 评论数 -1（未加载）时 Tab 仅显示"评论"无加载指示 | 显示小加载指示器 |

### 🟡 缺少图片占位符

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.22 | `lib/pages/live/widgets/live_item_app.dart` | 50-54 | 直播封面图无加载占位 | 添加背景色 + 居中进度指示器 |
| 4.23 | `lib/pages/live_follow/widgets/live_item_follow.dart` | 42-46 | 同上 | 同上 |
| 4.24 | `lib/pages/live_search/widgets/live_search_room.dart` | 42-46 | 同上 | 同上 |
| 4.25 | `lib/pages/dynamics/widgets/video_panel.dart` | 53-58 | 动态视频缩略图无加载占位 | 同上 |

### 🟡 缺少无障碍标签

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 4.26 | `lib/pages/live_room/widgets/chat_panel.dart` | 36-398 | 聊天消息用 Text.rich + TextSpan，屏幕阅读器无法区分用户名/勋章/内容 | 每条消息用 Semantics 包裹 |
| 4.27 | `lib/pages/live_room/widgets/header_control.dart` | 117-312 | ComBtn 有 tooltip 但无 Semantics 标签 | 添加与 tooltip 一致的 Semantics |


---

## 5. 个人主页/关注/收藏/历史/下载/订阅模块

### 🟡 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 5.1 | `lib/pages/member/view.dart` | 260 | 预约弹窗中的动态按钮 `iconButton(size: 32)` | 至少 36+ |
| 5.2 | `lib/pages/member_video/widgets/video_card_h_member_video.dart` | 196-204 | 视频弹出菜单按钮 29×29 | 改为 36+ |
| 5.3 | `lib/pages/history/widgets/item.dart` | 199-206 | 历史记录弹出菜单按钮 29×29 | 改为 36+ |
| 5.4 | `lib/pages/subscription/widgets/item.dart` | 140-153 | 订阅删除按钮 `Positioned(35×35)` | 至少 40 |
| 5.5 | `lib/pages/fav_detail/view.dart` | 399 | 收藏切换按钮 `iconButton(size: 28)` | 至少 36 |

### 🟡 缺少触摸反馈（GestureDetector 无 InkWell）

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 5.6 | `lib/pages/member/widget/user_info_card.dart` | 118 | 统计数字（粉丝/关注/获赞）GestureDetector 无涟漪 | 改用 InkWell |
| 5.7 | `lib/pages/member/widget/user_info_card.dart` | 202 | 用户名复制 GestureDetector 无反馈 | 改用 InkWell 或加 toast |
| 5.8 | `lib/pages/member/widget/user_info_card.dart` | 330 | UID 复制同上 | 同上 |
| 5.9 | `lib/pages/member/widget/user_info_card.dart` | 829 | 充电/舰队行 GestureDetector | 改用 InkWell |
| 5.10 | `lib/pages/member/widget/user_info_card.dart` | 955-957 | "也关注了" 行 GestureDetector | 改用 InkWell |
| 5.11 | `lib/pages/fav_panel/view.dart` | 53-88 | 收藏夹 ListTile 用 Builder 绕过 InkWell | 改用 StatefulBuilder |
| 5.12 | `lib/pages/history/view.dart` | 270-283 | 历史记录暂停提示 GestureDetector | 改用 InkWell 或 TextButton |

### 🟡 元素重叠

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 5.13 | `lib/pages/fav_detail/widget/fav_video_card.dart` | 210-214 | 取消收藏按钮 `bottom: -8` 越界，可能重叠下一个卡片 | 改为 `bottom: 0` |

### 🟢 布局混乱

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 5.14 | `lib/pages/download_manager/view.dart` | 214 | 统计标签 `Text('$value$label')` 显示 "5总计" 无空格 | 改为 `Text('$value $label')` |

### 🟡 缺少加载状态

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 5.15 | `lib/pages/member/view.dart` | 221-228 | 预约弹窗切换按钮异步 API 无 loading 指示 | 显示加载 spinner |

---

## 6. 通用组件模块

### 🔴 触摸目标过小

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 6.1 | `lib/common/widgets/button/icon_button.dart` | 20-23 | 默认 `size: 36` | 默认改为 44 |
| 6.2 | `lib/common/widgets/button/toolbar_icon_button.dart` | 20-22 | 同上 36×36 | 同上 |
| 6.3 | `lib/common/widgets/video_card/video_card_v.dart` | 137-147 | 视频弹出菜单 29×29 | 改为 40+ |
| 6.4 | `lib/common/widgets/video_card/video_card_h.dart` | 167-176 | 同上 29×29 | 同上 |

### 🟡 缺少触摸反馈

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 6.5 | `lib/common/widgets/button/more_btn.dart` | 29-33 | `moreTextButton` 用 GestureDetector + `HitTestBehavior.opaque` 无涟漪 | 改用 InkWell 或 TextButton |

### 🟡 主题/颜色问题

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 6.6 | `lib/common/widgets/simple_app_bar.dart` | 11 | `backgroundColor` 默认 `Colors.black`，亮色主题下不可用 | 改用 `Colors.transparent` 或主题色 |
| 6.7 | `lib/common/widgets/floating_navigation_bar.dart` | 84 | 固定宽度 86px/项，5+ 项时可能溢出屏幕 | 用 LayoutBuilder 自适应 |

### 🟢 无障碍问题

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 6.8 | `lib/common/widgets/avatars.dart` | 全局 | 头像无语义标签 | 传入用户名称作为标签 |
| 6.9 | `lib/common/widgets/radio_widget.dart` | 77 | Radio 选项文字仅视觉可见 | 用 MergeSemantics 统一标签 |
| 6.10 | `lib/common/widgets/video_card/video_card_v.dart` | 161 | 视频标题无语义标签 | 添加 Semantics |

### 🟡 移动端 radio 触摸目标

| # | 文件 | 行号 | 问题描述 | 建议修复 |
|---|------|------|----------|----------|
| 6.11 | `lib/common/widgets/radio_widget.dart` | 71-74 | 逻辑颠倒：移动端用 `shrinkWrap`，桌面用 `padded` | 交换：移动端用 padded，桌面用 shrinkWrap |


---

## 7. 系统性问题（贯穿全项目）

### 7.1 🔴 无国际化支持（l10n）

**所有用户可见字符串均为硬编码中文，无 `intl` 或 `flutter_localizations` 设置。**

涉及的所有模块和代表性文件：

| 模块 | 代表文件 | 示例字符串 |
|------|----------|-----------|
| 视频播放器 | `view.dart`, `header_control.dart`, `send_danmaku/view.dart` | '返回', '发弹幕', '评论', '简介', '播放列表', '弹幕设置', '画质', '举报' |
| 首页 | `home/view.dart`, `mine/view.dart` | '首页', '动态', '我的', '消息', '搜索' |
| 直播 | `live_room/view.dart`, `live_room/widgets/header_control.dart` | '发送弹幕', '刷新', '屏蔽', '全屏', '分享', '举报' |
| 评论 | `reply/widgets/reply_item_grpc.dart` | '没有更多了', '加载中...', '还没有评论', '回复', '取消', '确定', '举报' |
| 动态 | `dynamics/widgets/action_panel.dart`, `author_panel.dart` | '发布动态', '转发', '评论', '点赞', '更多', '稍后再看' |
| 设置 | 所有 setting/pages/ | 所有开关标签、选项文字 |
| 弹窗 | `dialog/dialog.dart`, `report.dart`, `export_import.dart` | '取消', '确认', '删除', '举报类型', '导入导出' |
| 通用 | 全部 context_menu/, video_popup_menu.dart 等 | '文本', '表情', '加入过滤', '取消选择' |

**建议修复：** 引入 `flutter_localizations` 和 `intl` 包，将所有字符串提取到 `.arb` 文件，全局引用 `AppLocalizations.of(context).xxx`。

### 7.2 🟡 缺少无障碍语义标签

大量交互元素缺少 `Semantics` / `semanticLabel` / `tooltip`，包括：

- 所有 `GestureDetector` 包裹的交互元素（无声明的语义角色）
- 部分 `IconButton` 缺失 `tooltip`
- 头像图片（`NetworkImgLayer`）无语义标签
- 颜色选择器色块无语义描述
- 聊天消息中用户名/勋章/内容无法区分
- 视频卡片标题无语义标签

### 7.3 🟡 移动端与桌面端适配不统一

- `radio_widget.dart` 中移动端用了 `shrinkWrap`（小触摸目标），桌面端反而用 `padded`
- 部分按钮硬编码 `tapTargetSize: .shrinkWrap` 未区分平台

### 7.4 🟡 缺少统一加载/空/错误状态处理

- 多处 Loading 状态返回空 widget（`SizedBox.shrink()` 或 `SliverToBoxAdapter()`）
- 空状态与错误状态混用（如搜索趋势为空时显示 HttpError）
- 加载中缺少 skeleton/shimmer 占位

---

## 8. 设计良好的模块

以下模块经扫描认为设计合理，无明显 UI/UX 问题：

| 模块 | 文件 | 优点 |
|------|------|------|
| 浮动导航栏 | `floating_navigation_bar.dart` | 动画流畅，触摸目标合理，颜色适配套 |
| 主布局 | `main_layout.dart` | 自定义 RenderObject，结构正确，hit test 准确 |
| 缩放适配 | `scale_app.dart` | 绑定层定制，无 UI 渲染问题 |
| 下载任务卡片 | `download_manager/widgets/download_task_card.dart` | 触摸目标合理，InkWell 使用正确 |
| 直播提醒 | `live_alert/` 系列 | 加载/空/错误状态处理完善 |
| 勋章组件 | `medal_widget.dart`, `medal_wall.dart` | 标准 Material 实现 |
| 订阅视频卡片 | `subscription_detail/widget/sub_video_card.dart` | 标准实现 |
| 下载详情 | `download/detail/widgets/item.dart` | InkWell 使用正确，功能完善 |
| 横竖视频卡片 | `video_card_v.dart`, `video_card_h.dart` | 布局合理（除弹出菜单按钮过小外） |
| 徽章组件 | `badge.dart` | 颜色主题自适应，弹性布局 |
| 跑马灯 | `marquee.dart` | 自定义 RenderObject 实现良好 |
| 展开组件 | `expandable.dart` | 动画正确 |
| 调色板 | `color_palette.dart` | 尺寸合理 |
| 自定义图标 | `custom_icon.dart`, `disabled_icon.dart` | 纯数据定义或 RenderObject 实现正确 |

---

## 优先级修复建议

### P0（严重用户体验问题，影响核心功能）

| 优先级 | 问题 | 影响范围 |
|--------|------|----------|
| P0 | 触摸目标 < 44px（18+ 处） | 所有模块，严重影响移动端操作 |
| P0 | 视频初始化纯黑屏无加载指示 | 视频播放核心体验 |
| P0 | 空状态误用 HttpError | 搜索趋势页、设置搜索页 |
| P0 | 颜色选择器滑块仅 4dp 宽 | 设置页面几乎无法使用 |

### P1（中等用户体验问题，影响日常使用）

| 优先级 | 问题 | 影响范围 |
|--------|------|----------|
| P1 | GestureDetector 大量替代 InkWell（15+ 处） | 用户点按无反馈，不确定是否触发 |
| P1 | 缺少加载状态（搜索建议、热门推荐、视频查询等） | 用户等待时困惑 |
| P1 | 图片未裁剪圆角 | 收藏夹卡片视觉不精致 |
| P1 | 统计标签无空格 | 下载管理器显示异常 |
| P1 | 元素重叠（投币页、收藏按钮越界等） | 视觉缺陷 |

### P2（长期改进，提升品质）

| 优先级 | 问题 | 影响范围 |
|--------|------|----------|
| P2 | 无国际化支持 | 阻碍非中文用户使用 |
| P2 | 缺少无障碍语义标签 | 屏幕阅读器无法使用 |
| P2 | 对比度不足（多处） | 可读性问题 |
| P2 | 动画/过渡缺失（搜索 Tab 无 splash） | 交互反馈缺失 |
| P2 | 自定义组件问题（tooltip 阻挡交互、导航栏溢出） | 边缘情况问题 |
| P2 | 图片加载无占位符（4 处直播/动态） | 空白区域视觉空洞 |

---

*报告生成日期：2026-08-01*
*扫描工具：6 路并行 Agent（video / home / search / live / member / widgets）*


---

# UI/UX Responsive Review — 2026-08-01

## Overview
Automated scan of 630 UI files for responsive layout issues. Found 63 issues total.

## Critical Issues (Overflow Risks)

### lib/pages/article_list/view.dart:112
- **Element**: `Row inside _buildHeader (SliverAppBar.medium flexibleSpace background)`
- **Issue**: Row with fixed-width thumbnail + non-flex Column containing long Text.rich meta lines; no Expanded/Flexible, so the column sizes to its full intrinsic width and overflows on narrow screens (anti-patterns #1/#2: hardcoded-width sibling + Row children that don't flex).
- **Why**: In a Row, non-flex children get unbounded maxWidth (confirmed in Flutter flex.dart _constraintsForNonFlexChild), so the Column and its Text.rich lines ('12.3万篇专栏  |  456万字  |  789次阅读' ≈ 240-260dp, and the date line '2026-08-01更新  |  文集号: 123456') lay out on single lines at intrinsic width. After the fixed 91dp image + 10dp gap and 12dp margins, only ~195dp is left on a 320dp screen and ~250dp on 375dp, so the stats Text.rich line overflows the Row (yellow/black-stripe RenderFlex overflow, clipped text).
- **Fix**: Wrap the info Column in Expanded/Flexible so it gets the remaining bounded width, and add maxLines + TextOverflow.ellipsis (or allow wrapping) on the Text.rich meta lines.


### F:\Repositories\GitHub\PiliPlus\lib\pages\dynamics\widgets\forward_panel.dart:111
- **Element**: `_forwardAuthor (Row > Text)`
- **Issue**: Row with two non-flexible Text children (author @name and timestamp) and no scroll/Flexible; the @name Text has no maxLines or TextOverflow.ellipsis.
- **Why**: On a 320dp screen the forwarded-card content is only ~266px wide (after outer 12px padding and the 15px container padding in forwardPanel). A UP name of ~14+ CJK chars at default font size plus the timestamp text (e.g. '08-01 12:30') exceeds the row width, and since Text in a Row lays out at full intrinsic single-line width, it triggers a RenderFlex overflow (yellow/black stripes). Larger system font scaling makes it worse.
- **Fix**: Wrap the author name Text in Flexible/Expanded with maxLines: 1 and overflow: TextOverflow.ellipsis (keep the timestamp as a trailing fixed child), or use Wrap.


### F:\Repositories\GitHub\PiliPlus\lib\pages\dynamics\widgets\module_panel.dart:244
- **Element**: `MEDIALIST Row / SizedBox(height:110) text column`
- **Issue**: DYNAMIC_TYPE_MEDIALIST Row: hardcoded 180x110 cover (NetworkImgLayer width:180) plus Expanded(child: SizedBox(height:110, child: Column)) whose title Text (lines 278-284) has no maxLines/overflow and wraps inside the narrow column.
- **Why**: On a 320dp screen the fixed 180px thumbnail + 14px gap leave only ~100px for the title column. At that width the titleMedium text wraps to 3+ lines; combined with the SizedBox(height:4) and subTitle, the content exceeds the fixed 110px height, causing a vertical RenderFlex overflow inside the Column. On wider screens the title fits 1-2 lines so the bug only shows on small phones.
- **Fix**: Make the cover width responsive (Expanded or LayoutBuilder with an aspect ratio) so the text column keeps a usable width, remove the fixed SizedBox(height:110) / replace with IntrinsicHeight or let the column size to content, and add maxLines + TextOverflow.ellipsis to the title.


### lib/pages/dynamics_topic/view.dart:281
- **Element**: `Row (view/discuss stats + like/fav buttons) in _buildAppBar.flexibleSpace`
- **Issue**: Bottom stats Row overflows: an unbounded `Text('...浏览 · ...讨论')` (no Flexible/maxLines/ellipsis) plus `Spacer` plus two fixed `OutlinedButton.icon` (like/fav counts) in one non-scrollable Row.
- **Why**: Non-flexible Text children in a Row lay out at their full intrinsic single-line width (no wrapping). On a 320dp screen the Row only has ~296dp (320 - 12 left - 12 right padding), but a typical payload like "12.4万浏览 · 1.3万讨论" (~170dp at fontSize 13) plus two count buttons (~85dp each + 10dp gap, ~184dp) needs ~354dp, so RenderFlex overflows with yellow/black stripes.
- **Fix**: Wrap the stats Text in Flexible with maxLines:1 and TextOverflow.ellipsis, and/or let the button group wrap onto its own line (e.g. a Wrap or a second Row), or constrain the buttons via LayoutBuilder/MediaQuery.


### lib/pages/fav/pgc/child_view.dart:125
- **Element**: `Row (bottom multi-select action bar, containing two '标记为X' GestureDetector buttons)`
- **Issue**: Anti-pattern #2/#8: Row with 9-10 fixed-width children and no scroll. The multi-select action bar Row always contains two '标记为X' status buttons, each wrapped in Padding(left: 25) + inner horizontal padding 5 + 5 CJK-char text (~105dp each), plus leading SizedBox(16), iconButton(size:32), SizedBox(12), Checkbox (~48), '全选' label (~40), trailing SizedBox(20). Only one Spacer() can absorb slack. Total fixed content ~370dp exceeds a 320dp-wide screen, so the Row overflows (yellow-black stripes) and the rightmost buttons get clipped. The same Container also uses a fixed height of bottomH = 50 + system inset, which overflows vertically when system text scale increases the label/button heights beyond 50dp.
- **Why**: On a 320-375dp phone the two status buttons (Padding left:25 each) plus checkbox/icon/'全选' total ~370dp fixed, so with only one Spacer the Row is ~50dp wider than the screen at 320dp. The bar is positioned as a non-scrollable fixed bar, so there is no way to recover; the '标记为X' actions clip. At larger accessibility text scales the fixed 50dp height also clips the taller labels/buttons vertically.
- **Fix**: Make the bar adaptive: wrap the Row in a horizontal SingleChildScrollView (or use Wrap) so extra buttons scroll instead of overflowing; replace the large Padding(left:25) per button with Wrap/Expanded spacing or smaller fixed gaps; drop the fixed height (use content-sized Container with SafeArea padding / EdgeInsets only) so it grows with text scale. Optionally use LayoutBuilder/MediaQuery to hide the '标记为X' text labels and show icon-only actions on narrow screens.


### lib/pages/fav/note/child_view.dart:69
- **Element**: `Container(height: bottomH) bottom action bar / Row`
- **Issue**: Anti-pattern #6: Fixed-height Container (height = bottomH = 50 + MediaQuery bottom inset) that does not adapt to text size. The child Row contains an iconButton (32), a Checkbox (~48 tall), a '全选' GestureDetector, and a FilledButton.tonal('删除') whose heights scale with the ambient textScaler. Any scale above ~1.15 pushes the button/checkbox content taller than the hardcoded 50dp, causing vertical overflow inside the clipped Container. The Row is also a fixed-content Row with a single Spacer and no scroll wrapper.
- **Why**: The bar height is pinned to 50 + system inset while its children (Checkbox, text labels, FilledButton) grow with MediaQuery text scale; on small phones (320dp) with accessibility/larger fonts the labels and the '删除' button exceed 50dp and overflow vertically (clip/stripes). The horizontal fixed content (~240dp) also has no scroll fallback if it ever grows past the available width.
- **Fix**: Remove the hardcoded height: let the Container size to its content, using EdgeInsets/SafeArea for the system inset instead of a fixed 50dp, or wrap the Row in a horizontal SingleChildScrollView and apply IntrinsicHeight/textScaler-aware layout so larger text expands the bar instead of overflowing.


### lib/pages/live/widgets/live_item_app.dart:200
- **Element**: `videoStat()`
- **Issue**: Overflowing Row with two non-flexible Text children and no ellipsis (anti-pattern 8): MainAxisAlignment.spaceBetween Row of Text(areaName) + Text(watchedShow.textLarge), neither wrapped in Expanded/Flexible.
- **Why**: On 320-375dp the card grid (maxCrossAxisExtent 240, cardSpace 8, margins 12) yields ~144dp cards, giving the overlay only ~124dp of usable width (card minus 20dp horizontal padding). Real Bilibili area names such as '哔哩哔哩英雄联盟赛事' are ~121px at fontSize 11, which alone nearly fills the overlay; adding textLarge like '100.2万人看过' (~78px) forces a RenderFlex overflow / clipped text, with no ellipsis to degrade gracefully.
- **Fix**: Wrap each child Text in Expanded/Flexible with overflow: TextOverflow.ellipsis (e.g. Expanded(child: Text(...))) inside the spaceBetween Row, or use a FittedBox/Flexible so long values shrink instead of overflowing.


### lib/pages/live_alert/widgets/live_alert_rule_editor_sheet.dart:126
- **Element**: `SegmentedButton<MatchTarget>`
- **Issue**: SegmentedButton with 3 wide labels: the control clamps each segment to availableWidth/segments (verified in Flutter SDK _calculateHorizontalChildSize: childWidth = min(max intrinsic width, maxWidth/childCount)), so a wide selected segment overflows its cell.
- **Why**: On a 320dp screen the sheet content is 320 - 32 (16dp ListView padding each side) = 288dp, so each of the 3 segments is forced to ~96dp. When the widest segment '标题或分区' is selected, showSelectedIcon (default true) renders a leading check icon inline, so the segment needs ~28 (M3 scaled padding 12+16) + 18 (icon) + 8 (gap) + 70 (label) ≈ 124dp > 96dp (and > ~114dp even on 375dp) -> RenderFlex overflow. Any text scale > ~1.1 overflows all three segments.
- **Fix**: Shorten the labels (e.g. '标题或分区' -> '任一'), set showSelectedIcon: false with a reduced visualDensity, or replace SegmentedButton with ChoiceChips inside a Wrap so wide items wrap to the next line instead of being forced into equal-width fixed cells.


### lib/pages/member_coin_arc/widgets/item.dart:113
- **Element**: `MemberCoinLikeItem`
- **Issue**: Overflowing Row with Flexible/Spacer but no scroll (anti-pattern #8): the stats row inside the card is `Row[StatWidget(play), SizedBox(8), StatWidget(danmaku), Spacer(), Text(date), SizedBox(6)]` with no Wrap/scroll and no ellipsis on the date.
- **Why**: On a 320-375dp phone the coin_arc grid (`SliverGridDelegateWithExtentAndRatio`, maxCrossAxisExtent 240) yields 2 columns; each card is only ~144dp wide and the stats row's usable width is ~131dp (144 - Card default margin 8 - padding-left 5). The two StatWidgets (Icon 13 + 2 gap + 12px text, up to ~55dp each for 万/亿-formatted counts like '9999万' or '1.2亿' via NumUtils.numFormat) plus an 8dp gap plus a date that can be '昨天 23:59' or 'yyyy-MM-dd' (~45-60dp at 11px) total ~150-175dp fixed min-width. Because `Spacer()` can only absorb remaining space after inflexible children are placed, the fixed children overflow the ~131dp row on any popular video, causing a RenderFlex overflow exception. Even moderate values (e.g. '1.2亿' play + '07-31' date) exceed it.
- **Fix**: Make the row overflow-proof: replace the `Spacer()` + bare date `Text` with the date wrapped in `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end))`, and wrap the whole stats row in `Wrap(spacing: 8)` (or make the two StatWidgets Flexible). Removing the trailing `SizedBox(width: 6)` also helps.


### lib/pages/mine/view.dart:105
- **Element**: `Row in _buildActions (Flexible + ConstrainedBox(maxWidth: 80) + AspectRatio(aspectRatio: 1))`
- **Issue**: Anti-patterns #3+#4: Row(mainAxisAlignment: spaceEvenly) of 5 action buttons, each wrapped in Flexible -> ConstrainedBox(maxWidth: 80) -> AspectRatio(aspectRatio: 1), forcing each button into a fixed small square. On a 320dp screen the Row splits 5 ways, giving each item only ~64dp; the 5th label '收藏的评论' (5 CJK chars ~65px at fontSize 13) no longer fits on one line, wraps, and the icon(24)+spacing(6)+2-line-text (~36) Column overflows the 64x64 AspectRatio box -> RenderFlex vertical overflow stripes and cramped text.
- **Why**: 5 items x maxWidth 80 = 400dp > 320dp, so Flexible squeezes each to ~64dp, but AspectRatio(1) then forces a tight 64x64 box; the icon+label content (~66dp tall and ~65dp wide) exceeds the box, so the middle column wraps and overflows on narrow screens. The maxWidth 80 cap also makes the buttons arbitrarily cramped instead of letting labels ellipsize.
- **Fix**: Remove ConstrainedBox(maxWidth: 80) and AspectRatio(1); lay the 5 actions out with Wrap (with run/vertical spacing) or a horizontally scrollable ListView, and let each item size to content with Text maxLines:1 + TextOverflow.ellipsis (e.g. FittedBox).


### lib/pages/member_upower_rank/view.dart:216
- **Element**: `Row (ListTile.title) in _buildBody / SliverList itemBuilder`
- **Issue**: Anti-pattern #1: ListTile title is a Row [NetworkImgLayer(width:38,height:38), SizedBox(spacing:12), Text(item.nickname!)] where the nickname Text has no Flexible/Expanded and no maxLines/overflow. The Text lays out at its full intrinsic width and cannot shrink, so a long CJK nickname pushes past the bounded title width and overflows horizontally.
- **Why**: On a 320dp screen the ListTile content width is already consumed by the scaled leading rank number, the trailing 'N 天' (~40px) and tile padding, leaving ~170-200dp for the title Row. The fixed 38px avatar + 12 spacing = 50dp fixed, so any nickname longer than ~8 CJK chars (~120px at fontSize 14) exceeds the available width -> RenderFlex overflow. The nickname comes straight from server data with no length cap.
- **Fix**: Wrap the nickname Text in Expanded/Flexible with maxLines: 1 and overflow: TextOverflow.ellipsis (and crossAxisAlignment center on the Row).


### lib/pages/music/view.dart:85
- **Element**: `Row (AppBar title, _buildAppBar)`
- **Issue**: AppBar title is a Row whose second child is a plain Text(response.musicTitle!) with no maxLines/overflow and not wrapped in Expanded/Flexible.
- **Why**: The title Text is a non-flex Row child laid out at unbounded width, so it renders at full intrinsic width with no truncation possible. Adding the 36dp cover + 8dp spacing, a music title longer than ~220dp exceeds the toolbar title area (~264dp on a 320dp screen), causing a RenderFlex overflow on narrow phones whenever the title is moderately long.
- **Fix**: Wrap the title Text (or the whole trailing content) in Expanded/Flexible and add maxLines: 1 with overflow: TextOverflow.ellipsis so long titles truncate instead of overflowing the AppBar.


### lib/pages/rank/zone/view.dart:66
- **Element**: `VideoCardH / StatWidget Row (grid cell)`
- **Issue**: SliverGrid.builder renders shared VideoCardH inside GridMixin's fixed gridDelegate (mainAxisExtent: 110, maxCrossAxisExtent: smallCardWidth*2 = 480). On phones this grid is always 1 column, so each VideoCardH's AspectRatio(16/10) cover is forced to ~160dp wide, and its bottom stats Row (two StatWidgets, no flex) overflows. Anti-pattern #4/#6 (AspectRatio + fixed-height container + Row with no flex/scroll).
- **Why**: On a 320dp phone the rank page gives content only ~266dp after the fixed 51dp VerticalTabBar sidebar. VideoCardH's padding (24dp) + AspectRatio cover width 160dp (height capped at 110-10=100dp by the fixed mainAxisExtent) + SizedBox(10) leave ~75dp for the text column. The stats Row (play icon+count ≈59dp, danmaku ≈43dp, spacing 8) needs ~110dp, so it overflows and the numbers are clipped. On ≥360dp phones it barely fits, which is why it only breaks on 320-345dp screens.
- **Fix**: Fix in VideoCardH (used by this page and rank's grid): wrap each StatWidget in Flexible or change the stat Row to Wrap, or add overflow/ellipsis to the stat text; alternatively make the grid delegate adaptive (reduce maxCrossAxisExtent / cap cover width) so the text column stays wide enough on small phones. In this page you can also cap the cover via a ConstrainedBox(maxWidth: ~120) around the AspectRatio.


### lib/pages/save_panel/view.dart:391
- **Element**: `Container(height: 81) wrapping Row with NetworkImgLayer(width/height from coverSize)`
- **Issue**: Fixed-height Container (height: 81) whose child NetworkImgLayer height is derived from coverSize = MediaQuery.textScalerOf(context).scale(65). Content area is only 65px tall (81 minus 2x8 padding), so at any text scale above 1.0 the image (and the adjacent Expanded title text) overflows the box.
- **Why**: On small phones users frequently run larger system font scales. With textScale 1.1 the image is ~71.5px inside a 65px content slot -> RenderFlex vertical overflow (yellow/black stripes in debug, clipped image bottom in release). The 88x88 QR block above already pushes content; this box is the one fixed-size element that does not adapt to scaled content (anti-pattern: fixed-height container not adapting to text/content).
- **Fix**: Size the container from the same scaled value instead of a literal: `height: coverSize + 16` (16 = the 2x8 padding) so image + padding stay consistent, or drop the fixed height and let the Row size naturally. coverSize is already textScaler-scaled, so reuse it.


## Moderate Issues

### lib/pages/article_list/widgets/item.dart:43
- **Element**: `AspectRatio in ArticleListItem`
- **Issue**: AspectRatio(aspectRatio: 16/10) placed directly as a Row child (anti-pattern #4: AspectRatio on an item that should flex; it has unbounded horizontal constraints and sizes off the row height instead of the available column width).
- **Why**: A bare AspectRatio in a Row receives infinite maxWidth (flex.dart _constraintsForNonFlexChild returns BoxConstraints(maxHeight:) for horizontal rows), so RenderAspectRatio._applyAspectRatio falls back to height = constraints.maxHeight (grid mainAxisExtent 110 minus 10dp vertical padding ≈ 100) and width = 100 × 1.6 = 160dp fixed. The thumbnail never adapts to the cell width: whenever the grid has ≥2 columns (tablets/landscape, or user lowers smallCardWidth to its 150dp minimum → a 320dp phone gets 2 columns of ~160dp and a 360dp phone cells of ~180dp, leaving only ~136-156dp for the row), the fixed 160dp image overflows the Row and squeezes the title column. The recent 'layoutbuilder patch' commit (89522e205) only patches the image inside the AspectRatio, not the AspectRatio's own sizing.
- **Fix**: Give the thumbnail an explicit bounded width before the AspectRatio (e.g. SizedBox(width: ~110, child: AspectRatio(...))) or wrap it in Flexible and size it from available width with a LayoutBuilder, so it scales with column width instead of row height.


### lib/pages/article/view.dart:434
- **Element**: `Row of textIconButton (TextButton.icon) in _buildBottom`
- **Issue**: Bottom action bar is a Row of four Expanded TextButton.icon whose fixed content (15dp horizontal padding on each side + 16dp icon + 8dp gap + formatted count label) has a minimum width larger than each button's share on small screens (anti-pattern #8: Fixed-content children in a Row that cannot shrink below their intrinsic min-width, no scroll/Wrap).
- **Why**: The bar spans the full screen width (the fab slot is laid out with constraints.loosen(), and the Row has Expanded children), so on a 320dp screen each button is forced to ~80dp with a ~50dp content area after the 30dp horizontal padding. TextButton.icon's internal Row (mainAxisSize.min) then needs icon 16 + gap 8 + label: a 2-char label '转发/分享/收藏/点赞' is ~28dp and a formatted count like '12.3万' is ~39dp, so 52-63dp > 50dp → the button's inner Row overflows (visible stripe/clipped count). Only fits comfortably at ≥350dp widths.
- **Fix**: Reduce the TextButton horizontal padding, replace the fixed icon+gap+label layout with Flexible/FittedBox + overflow ellipsis on the label, or make the action row horizontally scrollable (SingleChildScrollView) instead of four rigid Expanded buttons.


### PiliPlus/lib/pages/common/dyn/common_dyn_page.dart:103
- **Element**: `buildReplyHeader Row`
- **Issue**: Row(mainAxisAlignment: spaceBetween) with a dynamic reply-count Text and a TextButton.icon, neither wrapped in Flexible/Expanded, no ellipsis on the Text, inside a pinned header with only 18px of horizontal padding
- **Why**: The Row has non-flexible children whose content is dynamic (reply count Text('$x条回复') and a sort label). On 320dp screens combined with the elevated system font scale common on small Android phones (1.3-2.0x), the count text plus the TextButton.icon exceeds the ~302px available width; because Row does not wrap or scroll and the Text has no overflow handling, it renders the yellow/black overflow stripes in debug and clipped text in release. Even at default scale a large unformatted count could push the sort button off-screen.
- **Fix**: Wrap the reply-count Text in Flexible and give it overflow: TextOverflow.ellipsis (and maxLines: 1); optionally constrain the TextButton.icon label with an overflow too, or replace the Row with a Wrap so the button wraps to the next line on narrow screens.


### F:\Repositories\GitHub\PiliPlus\lib\pages\dynamics\widgets\additional_panel.dart:620
- **Element**: `ADDITIONAL_TYPE_MATCH Row (teamItem / title)`
- **Issue**: MATCH additional row: an unconstrained title (Text/Column at lines 592-612, no Flexible/ellipsis) followed by two Expanded team columns (each a 30px NetworkImgLayer inside EdgeInsets only(left/right:16)), a non-flexible center score Column, and an optional FilledButton.
- **Why**: On a 320dp screen the usable row width is ~272px. The non-flexible title (often 130-180px), center score column, and button consume most of it, leaving the two Expanded team columns only ~0-40px each. The 30px team logos plus 16px side padding overflow their shrunken cells (visual overlap) and a longer title pushes the row past the available width into RenderFlex overflow — the exact 'cramped squares' anti-pattern.
- **Fix**: Make the title Flexible/Expanded with ellipsis, or move the title onto its own full-width line above the Row; also reduce the team Padding to EdgeInsets.zero (or remove the fixed 30px image) and wrap in a scrollable/Wrap if content must stay inline.


### lib/pages/dynamics_topic/view.dart:1
- **Element**: `Import block / file header`
- **Issue**: Unresolved git merge-conflict markers (<<<<<<< HEAD / ======= / >>>>>>> upstream/main) wrap the entire import block, so this file fails to compile and the page cannot build or render at all.
- **Why**: The Dart compiler rejects the literal `<<<<<<<`, `=======`, and `>>>>>>>` tokens. Any layout is impossible because the whole file (and any import chain that pulls it in) won't compile, so this page breaks the app on every screen size, not just small phones.
- **Fix**: Resolve the conflict: keep the HEAD side (`package:pili_plus/...` imports), delete the duplicate `package:PiliPlus/...` block and the three conflict-marker lines, then re-verify the remaining symbols (e.g. SimpleScaffold) still resolve.


### lib/pages/dynamics_topic/view.dart:122
- **Element**: `ToggleButtons (sort tabs) in SliverPinnedHeader`
- **Issue**: Sort-bar ToggleButtons has no Wrap/scroll: it renders a data-driven list of tabs (allSortBy) in a plain Row with `constraints: BoxConstraints(minWidth: 54)`.
- **Why**: Flutter's ToggleButtons builds children inside an un-scrollable `Row(mainAxisSize: min)` (confirmed in toggle_buttons.dart). With 6 tabs at 54dp min each the Row needs 324dp, but on a 320dp screen only ~308dp is available (320 minus the 12dp left padding; there is no right padding), so RenderFlex overflows. Topic pages commonly return 5-6 sort options, and wider labels (e.g. "最多观看") push the threshold even lower.
- **Fix**: Wrap the ToggleButtons in a SingleChildScrollView(scrollDirection: Axis.horizontal) or replace it with a horizontally scrollable TabBar / Wrap so extra tabs scroll or wrap instead of overflowing.


### lib/pages/dynamics_topic_rcmd/view.dart:1
- **Element**: `Import block / file header`
- **Issue**: Unresolved git merge-conflict markers (<<<<<<< HEAD / ======= / >>>>>>> upstream/main) in the import block; the file fails to compile.
- **Why**: The literal conflict tokens are invalid Dart, so DynTopicRcmdPage cannot compile, which breaks the whole app build; the topic-recommendation list can never render on any device.
- **Fix**: Resolve the conflict: keep the `pili_plus/...` import set, delete the `PiliPlus/...` duplicate block and the marker lines.


### lib/pages/episode_panel/view.dart:3
- **Element**: `Import block / file header`
- **Issue**: Unresolved git merge-conflict markers (<<<<<<< HEAD / ======= / >>>>>>> upstream/main) wrap the import block; the file fails to compile.
- **Why**: Invalid Dart tokens break the build of EpisodePanel, which is used by the video player's episode/分P bottom sheet — nothing renders on any screen until resolved.
- **Fix**: Resolve the conflict: keep the `pili_plus/...` import block, drop the `PiliPlus/...` block and markers, then confirm symbols like `tabBarScrollPhysics` still exist.


### lib/pages/episode_panel/view.dart:673
- **Element**: `_buildToolbar Row (title, fav, jump-top/bottom/current, reverse, sort, close)`
- **Issue**: Toolbar is a non-scrollable Row with up to 7 fixed-width controls (title Text + `iconButton`s, each a `SizedBox(width: 36)`) and only a `Spacer` — no Flexible/Expanded or scroll.
- **Why**: Fixed children sum to ~312dp on the worst case (2-char title "合集" ~32dp + 7x36dp buttons + 28dp horizontal padding) against a 320dp screen, leaving only ~8dp slack. Any wider title, a system font scale above ~1.15, or an extra control pushes it past 320dp and RenderFlex overflows; there is zero flexibility in the layout.
- **Fix**: Make the toolbar scrollable (wrap in SingleChildScrollView horizontal) or shrink-to-fit (use Expanded/Flexible on the title, or LayoutBuilder/MediaQuery to drop/reflow buttons on narrow widths).


### lib/pages/episode_panel/view.dart:514
- **Element**: `NetworkImgLayer (episode cover) in _buildEpisodeItem Row`
- **Issue**: Hardcoded cover width: `NetworkImgLayer(width: 160, height: 100)` is a fixed non-flexing child of the episode Row, alongside an Expanded text column.
- **Why**: On a 320dp screen the fixed 160dp cover + 10dp spacing consumes half the panel width, leaving the Expanded title column only ~126dp (≈8 characters per line before ellipsis) and the cover does not shrink on narrower devices, producing a cramped, unbalanced layout rather than a proportional one.
- **Fix**: Give the cover a flexing width, e.g. Expanded(child: AspectRatio(aspectRatio: 16/10)) next to the Expanded text column, or scale the 160dp constant down with MediaQuery/LayoutBuilder on small screens.


### lib/pages/live_area/view.dart:1
- **Element**: `file header / import section`
- **Issue**: Build-blocking, not a layout pattern: the file contains unresolved git merge-conflict markers (<<<<<<< HEAD ... ======= ... >>>>>>> upstream/main) in the import block, leaving duplicated/conflicting imports (package:pili_plus vs package:PiliPlus).
- **Why**: The file cannot compile, so the page (and the whole app during `flutter analyze`/build) is broken regardless of screen size; no responsive behavior can be verified or rendered.
- **Fix**: Resolve the merge conflict by keeping one side (HEAD's package:pili_plus imports) and deleting the conflict markers, then re-run `flutter analyze` to confirm the file compiles.


### lib/pages/live_dm_block/view.dart:1
- **Element**: `file header / import section`
- **Issue**: Build-blocking, not a layout pattern: the file contains unresolved git merge-conflict markers (<<<<<<< HEAD ... ======= ... >>>>>>> upstream/main) in the import block, leaving duplicated/conflicting imports (package:pili_plus vs package:PiliPlus).
- **Why**: The file cannot compile, so the 弹幕屏蔽 page is broken regardless of screen size; no responsive behavior can be verified or rendered.
- **Fix**: Resolve the merge conflict by keeping one side (HEAD's package:pili_plus imports) and deleting the conflict markers, then re-run `flutter analyze` to confirm the file compiles.


### lib/pages/member_coin_arc/view.dart:1
- **Element**: `MemberCoinArcPage`
- **Issue**: Unresolved git merge conflict markers (`<<<<<<< HEAD`, `=======`, `>>>>>>> upstream/main`) spanning the entire import block (lines 1-26); the file will not parse/compile.
- **Why**: The Dart compiler rejects conflict markers in source, so this page cannot build at all — the widget tree never renders on any device/screen size (worst case of 'layout wrong'). The duplicate import blocks also reference `SimpleScaffold` and `package:PiliPlus/...` (old casing) on one side and `pili_plus` on the other, so the file is left in a broken half-merged state.
- **Fix**: Resolve the merge conflict: keep the current `pili_plus` import block (remove the `<<<<<<< HEAD` / `=======` / `>>>>>>> upstream/main` markers and the `package:PiliPlus/...` duplicate imports), then verify the file compiles with `flutter analyze`.


### lib/pages/member_favorite/widget/item.dart:65
- **Element**: `AspectRatio / MemberFavItem Row`
- **Issue**: AspectRatio (aspectRatio: Style.aspectRatio) is a non-flexible child of a Row; its width is derived from the fixed cell height, not the available width. Together with the trailing SizedBox(width:10) it forms a ~170px rigid segment that the Expanded text column has to fit around.
- **Why**: In this page the item sits in a SliverGrid with mainAxisExtent 110 (single full-width column on 320-375dp phones since maxCrossAxisExtent=480). The Row's inner height is ~100px (110 minus vertical padding), so the AspectRatio pins the thumbnail to 1.6*100 = 160px regardless of screen width, leaving only ~110px on a 320dp screen for the 2-line title + subtitle. Whenever the row is narrower than ~170px (e.g. the fav grid drops to 2 columns when the user lowers the smallCardWidth preference, or this widget is reused in a narrower slot) the AspectRatio + 10px gap + Expanded min-width exceeds the cell and triggers a horizontal RenderFlex overflow.
- **Fix**: Make the thumbnail flex: wrap it in Expanded/Flexible with a flex ratio, e.g. Expanded(flex: 3, child: AspectRatio(aspectRatio: Style.aspectRatio, child: LayoutBuilder(...))) and Expanded(flex: 4, child: textColumn), so it shrinks with the row width instead of being pinned by the cell height; or size it via LayoutBuilder from a fraction of the row width.


### lib/pages/member_home/widgets/fav_item.dart:45
- **Element**: `NetworkImgLayer / MemberFavItem Row`
- **Issue**: Hardcoded thumbnail size NetworkImgLayer(width: 160, height: 100) as a non-flexible Row child with a fixed SizedBox(width: 10) gap.
- **Why**: The 160px image + 10px gap is a rigid 170px segment inside the Row. On a 320dp phone (available ~296px after Style.safeSpace padding) the 2-line title column is squeezed to ~126px, and the fixed width does not scale with device size or text scale; if this item is ever placed in a parent narrower than ~170px (2-column layout, split view, or a smaller card-width setting) the Row overflows horizontally with the yellow/black error stripes. It also does not adapt to taller or narrower screen variants.
- **Fix**: Remove the hardcoded width/height and let the thumbnail flex with the row, e.g. Expanded(child: AspectRatio(aspectRatio: 1.6, child: NetworkImgLayer(...))) alongside an Expanded text column, or use LayoutBuilder to size the image as a fraction of available width instead of fixed 160.


### lib/pages/member_favorite/view.dart:172
- **Element**: `SliverGrid.builder / SizedBox(height: 110) / Container(height: 40)`
- **Issue**: Fixed-height layout that does not adapt to text size/content: grid cells hardcoded to mainAxisExtent 110 (Grid.videoCardHDelegate), each item additionally wrapped in SizedBox(height: 110), and a load-more Container(height: 40).
- **Why**: On small phones the two-line title plus the 12px metadata line must fit in the fixed 100px inner height of each 110px-tall grid cell. At default text scale it barely fits, but with the system font scaling typical on budget Android phones (1.3-1.5x) the title + subtitle exceed the fixed cell and the Column overflows/clips vertically inside the grid tile, and the fixed-height thumbnail (AspectRatio sized from that same height) then also compresses the already-narrow text column.
- **Fix**: Derive the cell height from the text scale, e.g. mainAxisExtent: MediaQuery.textScalerOf(context).scale(110) in Grid.videoCardHDelegate, and remove the redundant SizedBox(height: 110) wrapper so the tile can size to its content; make the load-more button height adaptive (min-height + padding) instead of a fixed Container(height: 40).


### lib/pages/mine/view.dart:142
- **Element**: `Row in _buildHeaderActions (IconButtons + msgBadge + BackButton)`
- **Issue**: Anti-pattern #2: _buildHeaderActions is a Row(mainAxisAlignment: end, spacing: 5) of up to 6-7 fixed-size IconButtons (iconSize 22 + EdgeInsets.all(8) padding) plus an optional Expanded BackButton and trailing SizedBox(width:16), with no Wrap or scroll. All children have fixed min widths, so when the optional actions are enabled (search + msgBadge shown because hasHome is false, plus star/incognito/switch/theme/settings, and/or showBackBtn when MinePage is pushed via MainController.toMinePage) the row exceeds 320dp.
- **Why**: The msgBadge IconButton uses the default 48dp min target (no shrinkWrap style) and the other icon buttons are ~38dp each; the fixed set totals ~312-322dp on a 320dp screen before the BackButton, so with home disabled + reply-cache toggle enabled, or when pushed with a back button, the non-flexible children sum exceeds the available width and RenderFlex overflows.
- **Fix**: Wrap the action buttons in a horizontal SingleChildScrollView or use OverflowBar, or derive the icon size/spacing from LayoutBuilder/MediaQuery (e.g. shrink icons on narrow widths), or move overflow actions into a PopupMenuButton.


### lib/pages/music/widget/music_video_card_h.dart:117
- **Element**: `Row (stats, content())`
- **Issue**: Row with two fixed StatWidgets (play + danmaku) inside the Expanded content column — no Flexible, Wrap, or scroll. The 16:10 AspectRatio thumbnail (line 65) derives its 160dp width from the grid cell's fixed 110dp height, leaving too little room for the content column on narrow screens.
- **Why**: The grid cell has a fixed mainAxisExtent of 110 (Grid.videoCardHDelegate), so the AspectRatio thumbnail is forced to 100*1.6 = 160dp wide on every screen. On a 320dp phone (1 column, cell=320dp), the content column is only 320 - 24 (safeSpace 12x2) - 160 (thumb) - 10 (gap) = ~126dp wide, but the two StatWidgets need ~134dp (13dp icon + 2dp gap + ~48dp 4-char formatted count each, plus 8dp spacing) and cannot shrink, so the inner Row throws a RenderFlex overflow (yellow/black stripes) at 320dp widths.
- **Fix**: Wrap the stats Row in a Wrap(spacing: 8) so the two stats flow to a second line when narrow, or wrap each StatWidget in Flexible/Expanded inside the Row, or size the thumbnail responsively (e.g. with LayoutBuilder fraction of cell width) instead of deriving its width from the fixed cell height.


### lib/pages/music/view.dart:567
- **Element**: `Row (rank stats, _buildCard / _buildRank)`
- **Issue**: Row with 4 fixed-width children ('热歌榜排名' label + 3 _buildRank stat columns) using MainAxisAlignment.spaceBetween — no Wrap, Flexible, or horizontal scroll.
- **Why**: Inside the Card (margin 8x2 + padding 16x2) a 320dp screen leaves only ~272dp of width. Each _buildRank column sizes to its widest text (rank number at 14dp bodyMedium can be up to 84dp for strings like '999.9万', labels like '使用稿件量' are 60dp) plus an 18dp arrow on the last item. With typical data the 4 items total ~246dp, but with larger formatted counts they reach ~312dp and overflow the Row with no fallback, since spaceBetween neither wraps nor clips.
- **Fix**: Replace the spaceBetween Row with a Wrap(spacing: 16, runSpacing: 8) so the rank columns wrap onto a second line, or wrap each _buildRank in Expanded/Flexible and ellipsize the labels.


### lib/pages/music/video/view.dart:80
- **Element**: `Row (SliverAppBar title, _buildAppBar)`
- **Issue**: SliverAppBar title is a Row (40dp cover + Column) where the Column is NOT wrapped in Expanded/Flexible. The title Text already has maxLines:1 + ellipsis but it cannot truncate because Row lays out non-flex children at unbounded width.
- **Why**: Non-flex children of a Row are laid out with an unbounded main axis, so the Column sizes to the full untruncated width of info.musicTitle. On a 320-375dp screen the toolbar title slot (after back button, no actions) is only ~264-310dp; a long bilibili music title (15+ CJK chars at titleMedium ≈ 240dp+) pushes the Row past the toolbar width and triggers a RenderFlex overflow instead of ellipsizing.
- **Fix**: Wrap the Column in Expanded so it receives the remaining bounded width, letting the existing maxLines:1 + TextOverflow.ellipsis on the title actually truncate long titles.


### lib/pages/pgc/view.dart:1
- **Element**: `N/A (no Flutter code in repo)`
- **Issue**: FILE NOT FOUND - audit blocked
- **Why**: None of the 16 listed files exist in this checkout. The repository F:/Repositories/GitHub/Happy-TTS contains zero .dart files, no pubspec.yaml, and no lib/pages/pgc, lib/pages/onboarding, lib/pages/pgc_index, or lib/pages/pgc_review directories (confirmed in the working tree and in all .claude/worktrees). This is a Node.js/TypeScript/React project (src/, frontend/src/), not a Flutter app, so there are no widgets to audit and no responsive layout bugs can be verified.
- **Fix**: Re-run this audit against the correct Flutter project checkout that contains lib/pages/pgc/, lib/pages/onboarding/, etc. Once the files are available, scan for the 9 listed anti-patterns (hardcoded widths, non-scrolling Rows, small ConstrainedBox maxWidth, inflexible AspectRatio, missing Wrap/SingleChildScrollView, fixed-height containers, unchecked MediaQuery.of, Overflowing Row with Flexible but no scroll, custom RenderObjects).


### lib/pages/popular_series/view.dart:194
- **Element**: `Row (in _buildSeriesList)`
- **Issue**: Row(spacing: 16, children: [label-with-arrow GestureDetector, Text(reminder)]) where the reminder Text is a raw non-flexible child with no Flexible/Expanded wrap and no maxLines/ellipsis. Anti-pattern #2/#5 (Row with growing non-flex text, no wrap/scroll).
- **Why**: The Bilibili weekly-list `reminder` string (e.g. '▸ 本期数据截止至 2026-07-26 12:00') is ~20+ CJK/ASCII glyphs. The Row sits in a SliverFloatingHeaderWidget padded to a max width of screen width minus ~14dp. On a 320dp phone the label ('第240期' ~70dp) + 16 spacing + arrow icon + the reminder's single-line intrinsic width (~230dp) exceeds the ~306dp available, so RenderFlex lays out overflow and the reminder text is clipped/bleeds off-screen (yellow-black overflow stripes in debug).
- **Fix**: Wrap the reminder Text in Expanded (or Flexible) with maxLines: 1, overflow: TextOverflow.ellipsis, or convert the whole Row to a Wrap(spacing: 16, runSpacing: 4); simplest is Expanded + ellipsis so the reminder truncates instead of overflowing.


### lib/pages/search_panel/pgc/view.dart:50
- **Element**: `gridDelegate (mainAxisExtent: 160)`
- **Issue**: SliverGridDelegateWithMaxCrossAxisExtent hardcodes mainAxisExtent: 160, but the grid cell's item (SearchPgcItem) has an intrinsic height of 164 (fixed 148px NetworkImgLayer + 16px vertical cardSpace padding). Every cell under-allocates by 4px.
- **Why**: SliverGrid gives the child a tight 160px height; the item needs 164, so the bottom ~4px of each card overflows into the next row (mainAxisSpacing is only 2px, so it visibly overlaps the following card). With large text scales the title Text.rich wraps to more lines and the overflow grows well beyond 4px, so it is worst on small phones with accessibility font sizes.
- **Fix**: Compute the extent from content, e.g. `mainAxisExtent: 148 + MediaQuery.textScalerOf(context).scale(16)` (mirrors how live/view.dart scales its extent), or omit mainAxisExtent and drive the cell height from childAspectRatio/content.


### lib/pages/search_panel/all/view.dart:67
- **Element**: `SizedBox(height: 160) around SearchPgcItem`
- **Issue**: SizedBox(height: 160) wraps SearchPgcItem, whose intrinsic height is 164 (148px image + 16px vertical padding). The hardcoded 160 box under-allocates by 4px (same mismatch as the pgc grid delegate).
- **Why**: The single PGC result branch forces a 160px box; the card's fixed 148px cover plus padding renders 164px, so the bottom of the card overflows/clips into the next waterfall item. Text scaling makes it worse (title can wrap). The sibling branch below (multi-PGC) already uses MediaQuery.textScalerOf for its height, so this branch is inconsistent.
- **Fix**: Use the same scaling approach as the multi-card branch: `height: 148 + MediaQuery.textScalerOf(context).scale(16)` (or 164) so the fixed 148px image + padding is fully contained.


### lib/pages/search_panel/article/widgets/item.dart:89
- **Element**: `Row(Text('${item.view}浏览'), Text(' • '), Text('${item.reply}评论'))`
- **Issue**: Row of three non-flexible Texts (view count, ' • ' separator, reply count) with no Flexible/FittedBox/ellipsis, inside an Expanded column that is only ~110-126px wide on a 320-375dp phone.
- **Why**: The article grid is a single column on phones (maxCrossAxisExtent 480 -> 1 column at 320dp). The fixed 16:10 cover AspectRatio consumes ~160px of the ~296px content row, leaving ~126px for the text column. Counts like '1000000浏览' (~65px) + ' • ' + '10000评论' (~53px) already sum past 126px, and Bilibili articles with >=1M views are common -> RenderFlex overflow, right edge clipped. On tablets the same cell gets a wider text column, so this only breaks on small phones.
- **Fix**: Wrap each Text in Flexible (with TextOverflow.ellipsis), or merge into a single Text with overflow handling, or format counts via NumUtils.numFormat and wrap the Row in FittedBox so long numbers scale down instead of overflowing.


### lib/pages/search_panel/user/widgets/item.dart:40
- **Element**: `Column (child of Row in SearchUserItem.build)`
- **Issue**: The info Column inside the card Row is NOT wrapped in Expanded/Flexible, so it is laid out with unbounded width and sizes to the intrinsic width of its widest child.
- **Why**: A Row lays out non-flex children with unbounded horizontal constraints, so the Column's width becomes the widest line (item.uname!, or the officialVerify.desc Text at line 66 which can be a long string like '知名游戏区UP主'). On a 320dp phone the grid cell is ~300dp wide; fixed siblings (SizedBox 15 + PendantAvatar 42 + SizedBox 10 = 67dp) plus an unwrapped long name/desc exceed the cell width, causing RenderFlex horizontal overflow (yellow/black stripes). Because the host SliverGrid also has a fixed mainAxisExtent of 66, a 3-line item clips vertically too.
- **Fix**: Wrap the Column in Expanded (or Flexible) so it takes the remaining width, and add maxLines: 1 + TextOverflow.ellipsis to the uname Text (and/or the officialVerify desc Text).


### lib/pages/search_panel/pgc/widgets/item.dart:82
- **Element**: `Row (meta info rows inside the Expanded column of SearchPgcItem)`
- **Issue**: The two metadata rows (lines 82-94 and 95-105) are Rows of plain Text children separated by '·' literals, with no Flexible/ellipsis.
- **Why**: In a Row, non-flex Text children are measured with unbounded width and therefore never wrap. On a 320dp screen the Expanded content area is only ~175dp wide (320 - 2*12 padding - 111 cover - 10 gap). Real data such as styles '日常/恋爱/搞笑' (~117dp) + '·' + indexShow '全13话' (~52dp) exceeds 175dp, producing RenderFlex overflow. The first meta row (areas + pubtime) can overflow too when the area string is long.
- **Fix**: Wrap the leading Text of each meta Row in Flexible with TextOverflow.ellipsis (or replace the Row with a Wrap), so long area/style/indexShow strings truncate instead of overflowing.


### lib/pages/search_panel/user/view.dart:53
- **Element**: `Row (buildHeader in _SearchUserPanelState)`
- **Issue**: buildHeader builds a Row with two maxLines:1 Texts ('排序: …' and '用户类型: …'), two Spacers, and a fixed 32x32 IconButton, with no Flexible wrapper and no ellipsis on the Texts.
- **Why**: Available width on a 320dp screen is ~283dp (320 - 25 - 12 padding). With the longest labels ('排序: Lv等级由高到低' ≈143dp + '用户类型: 认证用户' ≈91dp + 32dp button ≈ 266dp) it only fits at default text scale. The two Spacers collapse to 0 once intrinsic widths exceed available space, and because the Texts are non-flexible with maxLines:1 and no overflow, any accessibility text scaling or longer label triggers horizontal RenderFlex overflow.
- **Fix**: Wrap each Obx Text in Flexible with TextOverflow.ellipsis (keeping Spacer only for leftover space), or collapse to a single flexible status text plus the trailing filter button.


### lib/pages/search_panel/user/view.dart:95
- **Element**: `gridDelegate (SliverGridDelegateWithMaxCrossAxisExtent in _SearchUserPanelState)`
- **Issue**: SliverGridDelegateWithMaxCrossAxisExtent uses a hardcoded mainAxisExtent: 66 for user cells whose content height is variable.
- **Why**: SearchUserItem can render up to three stacked text lines (uname + '粉丝/视频' + officialVerify.desc). At default font that is ~54dp and fits in 66dp, but when the third line is present or the user enables text scaling (>=1.3x), the content exceeds the fixed 66dp cell. The Column uses mainAxisAlignment.center, so overflow is clipped symmetrically at both the top and bottom of the cell.
- **Fix**: Derive the extent from the text scaler, e.g. mainAxisExtent: 66 * MediaQuery.textScalerOf(context).scale(1), or enforce single-line ellipsis on all three Texts so the fixed height is safe.

