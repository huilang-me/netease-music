#!/bin/bash
# 🎵 网易云音乐综合脚本（获取歌单详情 + 批量下载）
# 脚本名称建议：netease-music.sh
# 用法:
#   bash netease-music.sh detail <playlist_id>   # 获取歌单歌曲详情
#   bash netease-music.sh download               # 批量下载 detail.json 中的歌曲
#   bash netease-music.sh all <playlist_id>      # 一条命令完成获取详情 + 下载
# 依赖: curl、jq

# --- 配置 ---
DETAIL_API="https://music.163.com/api/song/detail/?ids="
URL_API="https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id="
LYRIC_API="https://music-api.gdstudio.xyz/api.php?types=lyric&source=netease&id="

DOWNLOAD_DIR="download"
SLEEP_INTERVAL=5
DETAIL_JSON="detail.json"
IDS_JSON="ids.json"
FAIL_LOG="fail_record.json"

# --- 帮助 ---
usage() {
    echo "用法:"
    echo "  bash $0 detail <playlist_id>   # 获取歌单歌曲详情"
    echo "  bash $0 download               # 批量下载 detail.json 中的歌曲"
    echo "  bash $0 all <playlist_id>      # 获取歌单详情并自动下载"
    exit 1
}

# --- 参数检查 ---
if [ -z "$1" ]; then
    usage
fi

MODE="$1"

# --- 功能：获取歌单详情 ---
get_detail() {
    if [ -z "$2" ]; then
        echo "❌ 缺少歌单ID"
        exit 1
    fi

    PLAYLIST_ID="$2"

    echo "🔍 获取歌单 ID: $PLAYLIST_ID 的歌曲ID..."
    playlist_json=$(curl -s -L -H "User-Agent: Mozilla/5.0" "https://music.163.com/api/v6/playlist/detail?id=${PLAYLIST_ID}")

    code=$(echo "$playlist_json" | jq -r '.code // empty')
    if [ "$code" != "200" ]; then
        echo "❌ 获取歌单失败（code=$code）"
        exit 1
    fi

    ids=$(echo "$playlist_json" | jq '[.playlist.trackIds[].id]')
    if [ -z "$ids" ] || [ "$ids" == "null" ]; then
        echo "⚠️ 未提取到任何歌曲ID"
        exit 1
    fi

    echo "$ids" > "$IDS_JSON"
    count=$(echo "$ids" | jq 'length')
    echo "✅ 成功提取 $count 个歌曲ID，已保存到 $IDS_JSON"

    echo "🔍 获取歌曲详细信息..."
    ids_csv=$(echo "$ids" | jq -r '. | join(",")')
    req_url="${DETAIL_API}%5B${ids_csv}%5D"

    detail_json=$(curl -s -L --globoff \
      -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
      -H "Referer: https://music.163.com" \
      -H "Accept: application/json" \
      "$req_url")

    detail_code=$(echo "$detail_json" | jq -r '.code // empty')
    if [ "$detail_code" != "200" ]; then
        echo "❌ 获取歌曲详情失败（code=$detail_code）"
        exit 1
    fi

    detail_list=$(echo "$detail_json" | jq '[.songs[] | {
      id: .id,
      name: .name,
      artist: .artists[0].name,
      album: .album.name,
      pic: .album.blurPicUrl,
      year: (.album.publishTime / 1000 | todate | .[0:4])
    }]')

    echo "$detail_list" > "$DETAIL_JSON"
    echo "✅ 歌曲详情已保存到 $DETAIL_JSON"
}

# --- 功能：批量下载歌曲 ---
download_songs() {
    if [ ! -f "$DETAIL_JSON" ]; then
        echo "❌ 未找到 $DETAIL_JSON，请先获取详情"
        exit 1
    fi

    mkdir -p "$DOWNLOAD_DIR"

    mp3_fail=()
    lyric_fail=()
    cover_fail=()

    count=$(jq '. | length' "$DETAIL_JSON")
    echo "✅ 共检测到 $count 首歌曲"

    for ((i=0; i<$count; i++)); do
        id=$(jq -r ".[$i].id" "$DETAIL_JSON")
        name=$(jq -r ".[$i].name" "$DETAIL_JSON")
        artist=$(jq -r ".[$i].artist" "$DETAIL_JSON")
        album=$(jq -r ".[$i].album // empty" "$DETAIL_JSON")
        cover_url=$(jq -r ".[$i].pic // empty" "$DETAIL_JSON")

        display_name="${artist} - ${name} - ${album}"
        safe_name=$(echo "$display_name" | sed 's#[/:*?"<>|]#_#g')

        mp3_path="${DOWNLOAD_DIR}/${safe_name}.mp3"
        jpg_path="${DOWNLOAD_DIR}/${safe_name}.jpg"
        lrc_path="${DOWNLOAD_DIR}/${safe_name}.lrc"

        echo ""
        echo "🎶 [$((i+1))/$count] 处理歌曲：$display_name"
        request_flag=0

        # 下载 MP3
        if [ -f "$mp3_path" ]; then
            echo "✅ [$safe_name.mp3] 已存在，跳过下载"
        else
            url_req="${URL_API}${id}&br=320"
            url_json=$(curl -s "$url_req")
            url=$(echo "$url_json" | jq -r '.url // empty')

            if [ -z "$url" ] || [ "$url" == "null" ]; then
                echo "⚠️ [$display_name] 无法获取下载链接"
                mp3_fail+=("{\"id\":$id,\"name\":\"$name\",\"artist\":\"$artist\"}")
            else
                curl -L --retry 3 -o "$mp3_path" "$url"
                if [ $? -eq 0 ]; then
                    echo "✅ 下载完成：$safe_name.mp3"
                else
                    echo "⚠️ 下载失败：$safe_name.mp3"
                    mp3_fail+=("{\"id\":$id,\"name\":\"$name\",\"artist\":\"$artist\"}")
                fi
                request_flag=1
            fi
        fi

        # 下载封面
        if [ -n "$cover_url" ] && [ ! -f "$jpg_path" ]; then
            cover_full="${cover_url}?param=300y300"
            curl -s -L -o "$jpg_path" "$cover_full"
            if [ $? -eq 0 ]; then
                echo "✅ 封面已保存：$safe_name.jpg"
            else
                echo "⚠️ 封面下载失败：$safe_name.jpg"
                cover_fail+=("{\"id\":$id,\"name\":\"$name\",\"artist\":\"$artist\"}")
            fi
            request_flag=1
        fi

        # 下载歌词
        if [ ! -f "$lrc_path" ]; then
            lyric_req="${LYRIC_API}${id}"
            lyric_json=$(curl -s "$lyric_req")
            lyric=$(echo "$lyric_json" | jq -r '.lyric // empty')

            if [ -n "$lyric" ]; then
                echo "$lyric" > "$lrc_path"
                echo "✅ 歌词已保存：$safe_name.lrc"
                request_flag=1
            else
                echo "⚠️ 获取歌词失败：$safe_name.lrc"
                lyric_fail+=("{\"id\":$id,\"name\":\"$name\",\"artist\":\"$artist\"}")
                request_flag=1
            fi
        fi

        if [ $request_flag -eq 1 ]; then
            echo "💤 等待 $SLEEP_INTERVAL 秒，防止接口超频..."
            sleep $SLEEP_INTERVAL
        fi
    done

    # 输出失败记录
    echo "💾 保存失败记录到 $FAIL_LOG"
    cat <<EOF > "$FAIL_LOG"
{
  "mp3_fail": [$(IFS=,; echo "${mp3_fail[*]}")],
  "lyric_fail": [$(IFS=,; echo "${lyric_fail[*]}")],
  "cover_fail": [$(IFS=,; echo "${cover_fail[*]}")]
}
EOF

    echo ""
    echo "🎉 所有任务完成！文件保存在 ${DOWNLOAD_DIR}/"
    echo "⚠️ 下载失败/歌词失败/封面失败记录在 $FAIL_LOG"
}

# --- 执行模式 ---
case "$MODE" in
    detail)
        get_detail "$@"
        ;;
    download)
        download_songs
        ;;
    all)
        if [ -z "$2" ]; then
            echo "❌ 缺少歌单ID"
            exit 1
        fi
        get_detail "$@"
        download_songs
        ;;
    *)
        usage
        ;;
esac
