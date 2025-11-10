#!/usr/bin/env node
// mp3tag.js - MP3 批量合并封面、歌词并写入年份（根据 detail.json）
// 依赖：npm install node-id3
// 用法 node mp3tag.js

const fs = require("fs").promises;
const path = require("path");
const NodeID3 = require("node-id3");

const baseDir = process.argv[2] || ".";
const downloadDir = path.join(baseDir, "download");
const doneDir = path.join(baseDir, "done");
const skippedDir = path.join(baseDir, "skipped");
const logFile = path.join(baseDir, "mp3tag-log.json");
const detailJsonPath = path.join(baseDir, "detail.json");

const imageExts = [".jpg", ".jpeg", ".png"];
const results = { done: [], skipped: [], failed: [], skippedExisting: [] };

(async () => {
  // 读取 detail.json
  let detailData = [];
  try {
    detailData = JSON.parse(await fs.readFile(detailJsonPath, "utf8"));
  } catch (err) {
    console.warn("⚠️ 未找到 detail.json 或解析失败，将不会写入年份，也会跳过所有未匹配歌曲");
  }

  // 创建目录
  async function ensureDir(dir) {
    try { await fs.mkdir(dir, { recursive: true }); } catch {}
  }

  await ensureDir(doneDir);
  await ensureDir(skippedDir);

  // 查找封面
  async function findCover(base) {
    for (const ext of imageExts) {
      const file = path.join(downloadDir, base + ext);
      try { await fs.access(file); return file; } catch {}
    }
    return null;
  }

  // 查找歌词
  async function findLyrics(base) {
    const file = path.join(downloadDir, base + ".lrc");
    try { await fs.access(file); return file; } catch {}
    return null;
  }

  // 解析文件名
  function parseFileName(base) {
    const match = base.match(/^(.*?)\s*-\s*(.*?)\s*-\s*(.*)$/);
    if (match) return { artist: match[1].trim(), title: match[2].trim(), album: match[3].trim() };
    const match2 = base.match(/^(.*?)\s*-\s*(.*)$/);
    if (match2) return { artist: match2[1].trim(), title: match2[2].trim(), album: "" };
    return { artist: "", title: base, album: "" };
  }

  // 处理单个文件
  async function processFile(file) {
    const ext = path.extname(file).toLowerCase();
    if (ext !== ".mp3") return;

    const base = path.basename(file, ext);
    const srcPath = path.join(downloadDir, file);
    const destDone = path.join(doneDir, file);

    // done 已存在跳过
    try {
      await fs.access(destDone);
      console.log(`⏭️ done 已存在，跳过处理: ${file}`);
      results.skippedExisting.push(file);
      return;
    } catch {}

    const tags = parseFileName(base);

    // --- 匹配 detail.json ---
    const match = detailData.find(d => d.name === tags.title && d.artist === tags.artist);
    if (!match) {
      console.log(`⏭️ detail.json 中未找到歌曲 "${tags.title}" - "${tags.artist}"，跳过\n`);
      results.skipped.push(file);
      return; // ✅ 立即返回，后续不处理
    }

    // 写入年份
    if (match.year) tags.year = match.year;

    const imagePath = await findCover(base);
    const lyricPath = await findLyrics(base);

    if (!imagePath && !lyricPath) {
      const destSkipped = path.join(skippedDir, file);
      try { await fs.rename(srcPath, destSkipped); } catch {}
      console.log(`🚫 无封面与歌词，移动到 skipped: ${file}`);
      results.skipped.push(file);
      return;
    }

    try { await fs.copyFile(srcPath, destDone); } catch {}

    if (imagePath) {
      const mime = path.extname(imagePath).toLowerCase() === ".png" ? "image/png" : "image/jpeg";
      tags.image = { mime, type: { id: 3, name: "front cover" }, description: "cover", imageBuffer: await fs.readFile(imagePath) };
      console.log(`🖼️ 加入封面: ${path.basename(imagePath)}`);
    }

    if (lyricPath) {
      const lyrics = await fs.readFile(lyricPath, "utf8");
      tags.unsynchronisedLyrics = { language: "chi", text: lyrics };
      console.log(`📝 加入歌词: ${path.basename(lyricPath)}`);
    }

    console.log(`🎧 写入标签: 艺人="${tags.artist}" 歌曲="${tags.title}" 专辑="${tags.album || "（无）"}" 年份="${tags.year || "未知"}"`);

    try {
      const success = NodeID3.update(tags, destDone);
      if (success) {
        console.log(`✅ 生成完成: done/${file}\n`);
        results.done.push(file);
      } else throw new Error("写入失败");
    } catch (err) {
      console.error(`❌ 写入失败: ${file}`, err);
      results.failed.push(file);
    }
  }

  const files = await fs.readdir(downloadDir);
  for (const file of files) await processFile(file);

  await fs.writeFile(logFile, JSON.stringify(results, null, 2));
  console.log("🎵 所有文件处理完成，日志已保存到 mp3tag-log.json");
})();
