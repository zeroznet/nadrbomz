#!/usr/bin/env python3
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Opus 5.5)

import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET

PLAYER_URL = "https://www.youtube.com/youtubei/v1/player"
# The ANDROID InnerTube client gets caption URLs without a PO token; the web client does not.
ANDROID_VERSION = "20.10.38"
HEADERS = {
    "User-Agent": f"com.google.android.youtube/{ANDROID_VERSION} (Linux; U; Android 11) gzip",
    "Content-Type": "application/json",
}
VIDEO_ID_PATTERN = re.compile(r"(?:v=|youtu\.be/|shorts/|embed/|live/)([A-Za-z0-9_-]{11})")


def die(message):
    print(f"captions.py: {message}", file=sys.stderr)
    sys.exit(1)


def usage():
    print("usage: captions.py VIDEO_ID_OR_URL [LANG]  (LANG defaults to en)", file=sys.stderr)
    sys.exit(2)


def parse_video_id(arg):
    match = VIDEO_ID_PATTERN.search(arg)
    if match:
        return match.group(1)
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", arg):
        return arg
    die(f"Not a YouTube video ID or URL: {arg}")


def fetch_player(video_id):
    body = {
        "context": {"client": {"clientName": "ANDROID", "clientVersion": ANDROID_VERSION, "androidSdkVersion": 30}},
        "videoId": video_id,
    }
    request = urllib.request.Request(PLAYER_URL, json.dumps(body).encode(), HEADERS)
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def pick_track(player, video_id, lang):
    status = player.get("playabilityStatus", {})
    if status.get("status") != "OK":
        die(f"Video {video_id} not playable: {status.get('status')} {status.get('reason', '')}".rstrip())
    tracks = player.get("captions", {}).get("playerCaptionsTracklistRenderer", {}).get("captionTracks", [])
    if not tracks:
        die(f"Video {video_id} has no captions")
    matching = [t for t in tracks if t["languageCode"] == lang]
    if not matching:
        available = ", ".join(f"{t['languageCode']}{' (auto)' if t.get('kind') == 'asr' else ''}" for t in tracks)
        die(f"No '{lang}' captions on video {video_id}; available: {available}")
    return min(matching, key=lambda t: t.get("kind") == "asr")


def fetch_caption_text(track):
    request = urllib.request.Request(track["baseUrl"], headers=HEADERS)
    with urllib.request.urlopen(request) as response:
        root = ET.fromstring(response.read())
    return " ".join(text for p in root.iter("p") if (text := "".join(p.itertext()).strip()))


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[1] in ("-h", "--help"):
        usage()
    video_id = parse_video_id(sys.argv[1])
    lang = sys.argv[2] if len(sys.argv) == 3 else "en"
    track = pick_track(fetch_player(video_id), video_id, lang)
    print(fetch_caption_text(track))


if __name__ == "__main__":
    main()
