# 🎵 网易云音乐批量下载与 MP3 标签处理脚本

> **免责声明**
> 本项目中的下载功能来自第三方 **GD音乐台 (music.gdstudio.xyz)**，本站资源均来自网络，仅限本人学习参考。
> **严禁下载、传播或商用**，如侵权请与我联系删除。
> 继续使用本项目将视为同意本声明。

本项目提供一套 **网易云音乐下载和 MP3 标签处理工具**，支持：

1. 获取歌单详情（包含歌曲名、艺人、专辑、封面、年份等信息）
2. 批量下载歌曲、封面和歌词
3. 批量为 MP3 添加封面、歌词和年份标签，并将处理结果分类保存

适合希望批量管理网易云音乐收藏的用户。

---

## 📂 文件说明

* **`netease-music.sh`**
  Bash 脚本，主要功能：

  * 获取歌单详情 (`detail`)
  * 批量下载歌曲、封面、歌词 (`download`)
  * 一条命令完成获取详情 + 下载 (`all`)
* **`mp3tag.js`**
  Node.js 脚本，主要功能：

  * 根据 `detail.json` 为 MP3 批量添加 ID3 标签
  * 写入封面、歌词、年份信息
  * 自动分类：已处理 `done`、跳过 `skipped`、已存在 `skippedExisting`、处理失败 `failed`

---

## ⚙️ 依赖

### Bash 脚本

* `curl`
* `jq`

安装示例：

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install curl jq -y

# CentOS
sudo yum install curl jq -y
```

### Node.js 脚本

* Node.js 16+
* npm 包：`node-id3`

安装依赖：

```bash
npm install node-id3
```

---

## 💻 使用方法

### 一条命令完成获取详情并下载（推荐）

```bash
bash netease-music.sh all <playlist_id>
```

* `<playlist_id>` 可从网易云歌单链接获取，例如：

  ```
  链接: https://music.163.com/#/playlist?id=919939187
  歌单 ID 即为链接中的 id 参数: 919939187
  ```

* 会自动：

  1. 获取歌单详情 (`detail.json` / `ids.json`)
  2. 批量下载歌曲、封面和歌词到 `download/`
  3. 保存下载失败记录到 `fail_record.json`

> ⚠️ **说明**：你也可以单独使用 `detail` 或 `download` 模式：
>
> * 获取详情：`bash netease-music.sh detail <playlist_id>`
> * 批量下载：`bash netease-music.sh download`

---

### 批量写入 MP3 标签

```bash
node mp3tag.js
```

* 输入目录默认为当前目录，脚本会处理 `download/` 下的 MP3 文件
* 处理后：

  * 成功写入标签的文件保存到 `done/`
  * 无封面和歌词的文件保存到 `skipped/`
  * 已存在 `done/` 的文件跳过处理
* 日志文件：`mp3tag-log.json`

---

## 🗂️ 目录结构示例

```
.
├── netease-music.sh
├── mp3tag.js
├── detail.json
├── ids.json
├── fail_record.json
├── download/
│   ├── 歌曲1.mp3
│   ├── 歌曲1.jpg
│   └── 歌曲1.lrc
├── done/
│   ├── 歌曲1.mp3（包含歌曲名、艺人、专辑、封面、年份等信息）
├── skipped/
└── mp3tag-log.json
```

---

## ⚠️ 注意事项

1. **接口限制**

   * 下载接口依赖第三方 API，可能存在限流或不可用情况。
   * 脚本会自动等待 5 秒，可根据实际情况调整 `SLEEP_INTERVAL`。

2. **文件名安全**

   * 脚本会替换非法文件名字符（`/:*?"<>|` → `_`）。

3. **匹配 `detail.json`**

   * `mp3tag.js` 根据歌曲名和艺人匹配 MP3，确保下载文件名格式为：

     ```
     艺人 - 歌曲名 - 专辑名.mp3
     ```
   * 若未匹配到，MP3 会被跳过。

4. **Node.js 版本**

   * 推荐 Node.js 16 及以上，以确保 `fs.promises` 支持。

5. **多次运行**

   * 重复运行 `mp3tag.js` 不会覆盖 `done/` 目录中已处理文件。

---

## 🔧 配置选项

* `DOWNLOAD_DIR`：下载目录，默认 `download`
* `DETAIL_JSON`：歌曲详情文件，默认 `detail.json`
* `FAIL_LOG`：下载失败记录，默认 `fail_record.json`
* `SLEEP_INTERVAL`：下载间隔（秒），默认 `5`

---

## 📝 示例流程

```bash
# 一条命令获取歌单详情并下载
bash netease-music.sh all 123456789

# 写入 MP3 标签
node mp3tag.js
```

---

## ❤️ 贡献

欢迎 Fork 与 Star，提交 Issues 或 Pull Requests。
请遵守网易云音乐相关版权法规，仅用于个人学习和收藏使用。

---

## 📄 LICENSE

MIT License
