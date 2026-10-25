---
name: youtube
description: Reads a YouTube video through its captions with a stdlib Python script, no yt-dlp and no API keys, so the video can be summarized, quoted, or answered about. Use when the user shares a youtube.com or youtu.be link, names a video ID, or asks what a YouTube video says.
argument-hint: "<video-id-or-url> [lang]"
---

# youtube

## Purpose

Turn a YouTube video into text Claude can read. `captions.py` asks the InnerTube player endpoint as the ANDROID client, which returns caption URLs without a PO token, then flattens the caption XML into one line of plain text. Python 3.8+ stdlib only: install nothing.

## When NOT to use

- The answer depends on what is shown on screen (slides, code, diagrams). Captions carry speech only; say so instead of guessing at visuals.
- The user wants the video or audio file itself. This skill reads text, it does not download media.

## Workflow

1. **Pick the language.** Default `en`. Use the video's spoken language when it is clearly something else (a Slovak or Czech video → `sk` / `cs`).
2. **Fetch into the scratchpad.** Write the output to a file under the session's scratchpad directory, using its absolute path from the system prompt (there is no `$SCRATCHPAD` variable):

   ```sh
   python3 -I ~/.claude/skills/youtube/captions.py <video-id-or-url> <lang> > <scratchpad>/<video-id>.txt
   ```

   The first argument takes a bare 11-character ID or any `watch?v=`, `youtu.be/`, `shorts/`, `embed/` or `live/` URL.
3. **Read, then answer.** Read the file and summarize or answer from it. Long transcripts: read in parts rather than all at once.
4. **Delete the file** when the task is done, unless the user asked to keep the transcript.

## Errors

The script exits non-zero with one explicit line on stderr:

| Message | Meaning | Next step |
|---|---|---|
| `has no captions` | video has no caption tracks at all | tell the user; there is nothing to read |
| `No '<lang>' captions …; available: …` | requested language missing | rerun with a listed code, `(auto)` marks auto-generated tracks |
| `not playable: LOGIN_REQUIRED …` | age-gated, private, or members-only | tell the user; this route cannot read it |
| HTTP 400 / 403 traceback | ANDROID `clientVersion` in `captions.py` likely went stale | look up the current YouTube Android app version and bump `ANDROID_VERSION` in `claude/skills/youtube/captions.py` of the nadrbomz repo |

When both a manual and an auto-generated track exist in the language, the manual one wins.
