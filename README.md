# 记账本

一个纯本地的 Android 记账 App：记账、识图、分类、统计、多主题，数据只存手机，不联网不上传。

> 🔒 **本项目是私有仓库**，只有仓库所有者（你自己）能看到和下载，别人无法访问。

## 下载安装（手机端完整教程）

因为仓库是私有的，手机下载 APK 前需要先登录你的 GitHub 账号。按下面三步来：

### 第一步：手机浏览器登录 GitHub

1. 用**手机浏览器**打开 <https://github.com>
2. 点右上角菜单 → **Sign in / 登录**，输入你的 GitHub 账号和密码
3. 登录后点右上角头像 → **Your repositories / 你的仓库**，找到本项目仓库（如 `my-ledger`）

> 私有仓库不会出现在别人的搜索结果里，只有登录你自己的账号才看得到。

### 第二步：下载 APK 安装包

1. 进入仓库首页，在右侧栏找到 **Releases** 点进去（也可以直接在网址后加 `/releases`）
2. 点开最新版本（例如 `v1.1.0`）
3. 在 **Assets** 列表里找到 `ledger-app-v1.1.0.apk`（版本号随更新变化），点击下载
4. 浏览器提示"文件可能有害"时选**继续下载**——这是安卓对 APK 的常规提示，不是病毒

### 第三步：安装到手机

1. 下载完成后点开 APK 文件（或在手机「下载」文件夹里找到它）
2. 系统若提示"禁止安装未知来源的应用"，点**设置**，打开"允许安装未知来源应用"或"允许通过此浏览器安装"
3. 返回安装界面，点**安装**
4. 装好后桌面出现「我的账本」图标，点开即可使用

### 常见问题

| 问题 | 解决办法 |
|------|----------|
| 找不到 Releases 入口 | 仓库首页右侧栏，或访问 `https://github.com/你的用户名/仓库名/releases` |
| 下载完找不到文件 | 一般在手机「下载」文件夹，文件名含 `ledger-app` 和版本号 |
| 提示"解析包时出错" | APK 没下载完整，删掉重下；并确认手机安卓版本 ≥ 5.0 |
| 安装被系统拦截 | 设置 → 安全 → 安装未知应用，给浏览器开启安装权限 |
| 手机登录 GitHub 麻烦 | 可在电脑上登录后下载 APK，再用数据线或微信文件传输助手传到手机安装 |

> APK 由 GitHub Actions 云端自动构建并发布到 Releases，不需要自己编译。每次打新 tag，Releases 里就会多一个新版本。

## 功能

- **首页**：本月支出/收入/结余一览，常用分类快捷记账，最近账单（每笔带支付方式标签）
- **识图记账**：拍小票或从相册选图（支持微信/支付宝账单截图），手机本地 OCR 自动识别金额/日期/支付方式，核对后一键回填（图片不上传，离线可用）
  - 支付方式识别：零钱/零钱通 → 微信，花呗/余额宝/余额 → 支付宝，银行卡尾号/信用卡/储蓄卡 → 银行卡，现金 → 现金；识别结果可在弹窗中手动更正
  > 说明：识图用的是 Google ML Kit，需要手机装有 Google Play 服务。大多数安卓机支持；部分国产机型（如华为新机）可能提示"识别服务不可用"，此时手动填金额即可，不影响其它功能。
- **记账**：选收支 → 输入金额 → 选支付方式 → 点分类 → 保存，可填备注和日期
- **明细**：按月份切换，账目按日期分组，每笔显示支付方式，长按可删除
- **支付方式**：微信 / 支付宝 / 银行卡 / 现金 / 其他，记账时选择，账单上以彩色标签醒目显示
- **统计**：周 / 月 / 年 / 自定义日期区间四种模式，含分类占比饼图和收支趋势图
- **分类管理**：支出与收入各自独立，预设 12 + 7 类，均可改名；自定义分类可增删改
- **主题**：卡通糖果、清新简约、暗夜商务、暖阳橘、森林绿、天空蓝共 6 套，切换后自动记忆

## 技术实现

- Flutter（Dart）+ SQLite（`sqflite`）本地数据库
- 金额以「分」为单位用整数存储，彻底避免浮点精度误差
- 图表使用 Flutter 原生 `CustomPainter` 绘制，无第三方图表依赖
- 主题与数据全部本地持久化（`shared_preferences` + SQLite）

## 本地开发（可选）

如需在自己电脑上运行，需先安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)（stable 频道）和 Android Studio / Android SDK：

```bash
flutter create --platforms=android --project-name ledger_app --org com.ledger .
flutter pub get
flutter run
```

## 发布新版本（维护者）

打一个版本 tag 并推送，GitHub Actions 会自动构建 APK 并发布到 Releases。

### 第一次使用（把本项目推上 GitHub）

```bash
# 1. 在 GitHub 网页上先创建一个空仓库，例如 my-ledger，不要初始化 README

# 2. 在本项目目录执行（替换成你的仓库地址）
git init
git add .
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/my-ledger.git
git push -u origin main

# 3. 打版本 tag 触发自动构建
git tag v1.1.0
git push origin v1.1.0
```

### 后续更新版本

```bash
git add .
git commit -m "update"
git push origin main
git tag v1.0.1
git push origin v1.0.1
```

推送 tag 后到仓库的 **Actions** 页签看构建进度（约 5-10 分钟），成功后 APK 出现在 **Releases** 页。

> 若 Actions 因未开启权限失败：仓库 **Settings → Actions → General → Workflow permissions** 勾选「Read and write permissions」，重新推送 tag。
