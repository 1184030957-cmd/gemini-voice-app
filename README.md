# Gemini 语音对话 App

一个简单的 Android 语音对话应用，使用 Gemini API。

## 功能
- 按住麦克风说话
- 自动识别语音转文字
- 调用 Gemini API 对话
- 语音播放回复
- **API Key 在 App 内配置，安全存储在本地**

## 如何使用

### 下载安装
1. 进入仓库的 [Actions](../../actions) 页面
2. 点击最新的成功运行（绿色勾 ✓）
3. 下载 `gemini-voice-app` 文件
4. 解压得到 `app-release.apk`
5. 传到手机安装（需允许"未知来源"）

### 首次使用
1. 打开 App
2. 填写配置信息：
   - **API 地址**：你的 API 服务地址（已预填默认值）
   - **API Key**：你的 API 密钥
   - **模型名称**：使用的模型（已预填默认值）
3. 点击"保存并开始使用"
4. 配置会保存在手机本地，以后无需重复输入

### 修改配置
- 点击右上角设置图标
- 重新输入配置信息

## 安全说明
- ✅ API Key **不在代码中**，可安全公开仓库
- ✅ Key 保存在手机本地，加密存储
- ✅ 每个用户使用自己的 Key

## 本地打包（可选）
需要安装 Flutter SDK：
```bash
flutter pub get
flutter build apk --release
```
APK 位置：`build/app/outputs/flutter-apk/app-release.apk`

## 更新 App
修改代码后推送到 GitHub，Actions 会自动打包新版本，下载后覆盖安装即可。

## 注意事项
- 首次使用需要授权麦克风权限
- 需要联网使用
