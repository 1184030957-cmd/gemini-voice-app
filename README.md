# Gemini 语音对话 App

一个简单的 Android 语音对话应用，使用 Gemini API。

## 功能
- 按住麦克风说话
- 自动识别语音转文字
- 调用 Gemini API 对话
- 语音播放回复

## 如何使用

### 方法 1：下载已打包的 APK（最简单）
1. 等待 GitHub Actions 自动打包完成（推送代码后约 10 分钟）
2. 进入仓库的 Actions 页面
3. 点击最新的 workflow run
4. 下载 `gemini-voice-app` 文件
5. 传到手机安装

### 方法 2：本地打包
需要安装 Flutter SDK：
```bash
flutter pub get
flutter build apk --release
```
APK 位置：`build/app/outputs/flutter-apk/app-release.apk`

## 修改 API 配置
编辑 `lib/main.dart` 第 24-26 行：
```dart
final String apiUrl = "你的API地址";
final String apiKey = "你的API密钥";
final String model = "模型名称";
```

## 上传到 GitHub 步骤

### 1. 创建 GitHub 仓库
- 访问 github.com，登录
- 点击右上角 "+" → "New repository"
- 仓库名随意（如：gemini-voice-app）
- 选择 Public（公开仓库才能免费用 Actions）
- 不要勾选任何初始化选项
- 点击 "Create repository"

### 2. 上传代码
在当前文件夹打开终端，执行：
```bash
cd gemini_voice_app
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

### 3. 等待自动打包
- 推送后自动开始打包
- 进入仓库页面 → Actions 标签
- 等待绿色勾（约 10 分钟）
- 点击进入 → 下载 APK

## 注意事项
- 首次使用需要授权麦克风权限
- 需要联网使用
- API Key 已写在代码里，仅供个人使用
