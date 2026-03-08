import { tool } from 'ai';
import { z } from 'zod';

// YouTube transcript extraction via yt-dlp on Mac agent
// Brain: youtube-transcript-tool
// Brain: reddit-datacenter-ip-block (YouTube blocks datacenter IPs — route through Mac)
// Uses the same Python script as the Quack youtube-transcript skill

const MAC_URL = process.env.MAC_AGENT_URL;
const MAC_TOKEN = process.env.MAC_AGENT_TOKEN;

const SCRIPT_PATH =
  '/Users/alekdob/.claude/skills/youtube-transcript/scripts/extract_transcript.py';

interface YtDlpOutput {
  title: string;
  channel: string;
  duration: number;
  duration_string: string;
  language: string;
  is_auto_generated: boolean;
  chapters: Array<{ title: string; start_time: number }>;
  transcript: Array<{ start: number; text: string }>;
  available_languages: string[];
}

function extractVideoId(input: string): string | null {
  const patterns = [
    /(?:youtube\.com\/watch\?v=)([a-zA-Z0-9_-]{11})/,
    /(?:youtu\.be\/)([a-zA-Z0-9_-]{11})/,
    /(?:youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/,
    /(?:youtube\.com\/shorts\/)([a-zA-Z0-9_-]{11})/,
  ];
  for (const pattern of patterns) {
    const match = input.match(pattern);
    if (match) return match[1];
  }
  if (/^[a-zA-Z0-9_-]{11}$/.test(input)) return input;
  return null;
}

function formatTimestamp(seconds: number): string {
  const totalSec = Math.floor(seconds);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0)
    return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

// Run yt-dlp Python script via Mac agent (residential IP, yt-dlp installed)
async function runYtDlpViaMac(
  videoUrl: string,
  language: string,
): Promise<YtDlpOutput> {
  if (!MAC_URL || !MAC_TOKEN) {
    throw new Error('Mac agent not configured (MAC_AGENT_URL/MAC_AGENT_TOKEN)');
  }

  const langArg = language ? ` --lang ${language}` : '';
  const cmd = `osascript -e 'do shell script "PATH=/opt/homebrew/bin:/usr/bin:/bin python3 ${SCRIPT_PATH} \\"https://www.youtube.com/watch?v=${videoUrl}\\"${langArg}"'`;

  const res = await fetch(`${MAC_URL}/exec`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${MAC_TOKEN}`,
    },
    body: JSON.stringify({ command: cmd }),
    signal: AbortSignal.timeout(60000),
  });

  const data = (await res.json()) as {
    stdout?: string;
    stderr?: string;
    error?: string;
  };

  if (data.error) {
    // Check for specific exit codes in osascript error messages
    if (data.error.includes('stato non-zero') || data.error.includes('non-zero')) {
      const stderr = data.stderr || data.error;
      if (stderr.includes('No subtitles available')) {
        throw new Error('No subtitles available for this video');
      }
      if (stderr.includes('unavailable') || stderr.includes('Private video')) {
        throw new Error('Video is unavailable or private');
      }
      throw new Error(`yt-dlp failed: ${stderr.slice(0, 200)}`);
    }
    throw new Error(`Mac agent error: ${data.error.slice(0, 200)}`);
  }

  const stdout = data.stdout?.trim();
  if (!stdout) {
    throw new Error('Empty response from yt-dlp');
  }

  return JSON.parse(stdout) as YtDlpOutput;
}

export const youtubeTranscript = tool({
  description:
    'Get the transcript/subtitles of a YouTube video. Accepts a URL or video ID. Returns the full text with timestamps.',
  inputSchema: z.object({
    url: z.string().describe('YouTube video URL or video ID'),
    language: z
      .string()
      .default('en')
      .describe('Preferred language code (e.g. en, it, es)'),
    includeTimestamps: z
      .boolean()
      .default(false)
      .describe('Include timestamps in the transcript'),
    maxLength: z
      .number()
      .default(30000)
      .describe('Max characters to return'),
  }),
  execute: async ({ url, language, includeTimestamps, maxLength }) => {
    const videoId = extractVideoId(url);
    if (!videoId) {
      return { error: 'Invalid YouTube URL or video ID' };
    }

    try {
      const result = await runYtDlpViaMac(videoId, language);

      if (!result.transcript || result.transcript.length === 0) {
        return {
          error: 'No transcript available',
          videoId,
          title: result.title,
          channel: result.channel,
          duration: result.duration_string,
          availableLanguages: result.available_languages,
        };
      }

      // Build transcript text
      let transcript: string;
      if (includeTimestamps) {
        transcript = result.transcript
          .map((s) => `[${formatTimestamp(s.start)}] ${s.text}`)
          .join('\n');
      } else {
        transcript = result.transcript.map((s) => s.text).join(' ');
      }

      // Truncate safely (avoid splitting surrogate pairs)
      // Brain: fix-sessions-surrogate-pair-truncation
      let truncated = false;
      if (transcript.length > maxLength) {
        let end = maxLength;
        const code = transcript.charCodeAt(end - 1);
        if (code >= 0xd800 && code <= 0xdbff) end--;
        transcript = transcript.slice(0, end);
        truncated = true;
      }

      return {
        videoId,
        title: result.title,
        channel: result.channel,
        duration: result.duration_string,
        language: result.language,
        isAutoGenerated: result.is_auto_generated,
        segmentCount: result.transcript.length,
        chapters: result.chapters.length > 0 ? result.chapters : undefined,
        availableLanguages: result.available_languages,
        transcript,
        truncated,
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return {
        error: message,
        videoId,
      };
    }
  },
});
