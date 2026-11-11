#!/usr/bin/env bash
# 検証用ページを、専用 Xvfb 上の実 Chrome で 375px 再生し、ループ GIF にする。
# 共有デスクトップは使わない（他エージェント／個人データを撮らないため）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/docs/screenshots"
OUT_GIF="$OUT_DIR/before-after-375.gif"
OUT_MP4="$OUT_DIR/before-after-375.mp4"
PROOF="${PROOF_GIF:-/workspace/plans/images/proof/wp-375-before-after.gif}"
DISP="${WP_GIF_DISPLAY:-:98}"
PORT="${WP_GIF_PORT:-8765}"
W=375
H=720
SECS="${WP_GIF_SECS:-10}"

mkdir -p "$OUT_DIR" /workspace/plans/images/proof
rm -rf /tmp/chrome-wp-gif
mkdir -p /tmp/chrome-wp-gif/Default
# 翻訳バーが出ないようにする（英語 UI の Chrome が日本語ページを検出するため）
printf '%s' '{"translate":{"enabled":false}}' > /tmp/chrome-wp-gif/Default/Preferences

cleanup() {
  if [[ -n "${CHROME_PID:-}" ]]; then kill "$CHROME_PID" 2>/dev/null || true; fi
  if [[ -n "${HTTP_PID:-}" ]]; then kill "$HTTP_PID" 2>/dev/null || true; fi
  if [[ -n "${XVFB_PID:-}" ]]; then kill "$XVFB_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT

if [[ -S /tmp/.X11-unix/X${DISP#:} ]]; then
  DISP=":96"
fi

Xvfb "$DISP" -screen 0 ${W}x${H}x24 -ac +extension GLX +render -noreset >/tmp/wp-gif-xvfb.log 2>&1 &
XVFB_PID=$!
sleep 0.35
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
  echo "Xvfb failed" >&2
  cat /tmp/wp-gif-xvfb.log >&2
  exit 1
fi
DISPLAY="$DISP" xsetroot -solid "#111111" 2>/dev/null || true

python3 -m http.server "$PORT" --directory "$ROOT" --bind 127.0.0.1 >/tmp/wp-gif-http.log 2>&1 &
HTTP_PID=$!
sleep 0.3

DISPLAY="$DISP" LANGUAGE=ja LANG=ja_JP.UTF-8 google-chrome \
  --lang=ja --accept-lang=ja-JP,ja \
  --no-first-run --no-default-browser-check --disable-sync --disable-translate \
  --disable-features=Translate,TranslateUI,InfiniteSessionRestore,ChromeWhatsNew \
  --disable-session-crashed-bubble --disable-infobars --disable-notifications \
  --disable-dev-shm-usage --disable-gpu --disable-software-rasterizer \
  --force-device-scale-factor=1 \
  --window-position=0,0 --window-size=${W},${H} \
  --user-data-dir=/tmp/chrome-wp-gif \
  --kiosk "http://127.0.0.1:${PORT}/examples/record-375.html" \
  >/tmp/wp-gif-chrome.log 2>&1 &
CHROME_PID=$!

for i in $(seq 1 40); do
  if DISPLAY="$DISP" xwininfo -root -tree 2>/dev/null | grep -qi chrome; then
    break
  fi
  sleep 0.2
done
sleep 0.8
DISPLAY="$DISP" xdotool mousemove $((W-2)) $((H-2)) 2>/dev/null || true

ffmpeg -y -nostdin \
  -f x11grab -video_size ${W}x${H} -framerate 15 -i "${DISP}+0,0" \
  -t "$SECS" \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
  -c:v libx264 -pix_fmt yuv420p -preset veryfast -crf 18 \
  "$OUT_MP4" >/tmp/wp-gif-ffmpeg.log 2>&1

/workspace/demos/record.sh convert "$OUT_MP4" "$OUT_GIF"
if [[ -n "${PROOF}" && -d "$(dirname "$PROOF")" ]]; then cp -f "$OUT_GIF" "$PROOF"; fi

python3 - "$OUT_GIF" "$OUT_MP4" "$PROOF" << 'ENDPY'
import os, subprocess, sys
gif, mp4, proof = sys.argv[1], sys.argv[2], sys.argv[3]
size = os.path.getsize(gif)
print(f"gif bytes={size} ({size/1024/1024:.2f} MiB)  path={gif}")
print(f"mp4 bytes={os.path.getsize(mp4)}")
if size > 3 * 1024 * 1024:
    print("over 3MB, recompressing...", file=sys.stderr)
    tmp = "/tmp/wp-gif-small.gif"
    subprocess.check_call([
        "ffmpeg", "-y", "-i", mp4,
        "-vf", "fps=10,scale=375:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5",
        "-loop", "0", tmp,
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.replace(tmp, gif)
    size = os.path.getsize(gif)
    print(f"recompressed gif bytes={size} ({size/1024/1024:.2f} MiB)")
    if size > 3 * 1024 * 1024:
        sys.exit("still over 3MB")
os.replace  # keep import used
import shutil
shutil.copyfile(gif, proof)
ENDPY

echo "WP GIF ready: $OUT_GIF"
ls -lh "$OUT_GIF" "$PROOF" "$OUT_MP4"
