import { tool } from 'ai';
import { z } from 'zod';

interface TranscriptSegment {
  text: string;
  duration: number;
  offset: number;
}

interface VideoMetadata {
  title: string;
  author_name: string;
  thumbnail_url: string;
}

function extractVideoId(input: string): string | null {
  // Handle various YouTube URL formats
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
  // Maybe it's already a video ID
  if (/^[a-zA-Z0-9_-]{11}$/.test(input)) return input;
  return null;
}

async function fetchMetadata(videoId: string): Promise<VideoMetadata | null> {
  try {
    const url = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`;
    const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
    if (!res.ok) return null;
    return await res.json() as VideoMetadata;
  } catch {
    return null;
  }
}

function formatTimestamp(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

// Brain: youtube-transcript-tool
export const youtubeTranscript = tool({
  description:
    'Get the transcript/subtitles of a YouTube video. Accepts a URL or video ID. Returns the full text with timestamps.',
  inputSchema: z.object({
    url: z.string().describe('YouTube video URL or video ID'),
    language: z.string().default('en').describe('Preferred language code (e.g. en, it, es)'),
    includeTimestamps: z.boolean().default(false).describe('Include timestamps in the transcript'),
    maxLength: z.number().default(30000).describe('Max characters to return'),
  }),
  execute: async ({ url, language, includeTimestamps, maxLength }) => {
    const videoId = extractVideoId(url);
    if (!videoId) {
      return { error: 'Invalid YouTube URL or video ID' };
    }

    // Fetch metadata and transcript in parallel
    const { YoutubeTranscript } = await import('youtube-transcript');
    const [metadata, segments] = await Promise.all([
      fetchMetadata(videoId),
      YoutubeTranscript.fetchTranscript(videoId, { lang: language }).catch(
        (err: Error) => ({ error: err.message }),
      ),
    ]);

    if ('error' in segments) {
      return {
        error: `Failed to fetch transcript: ${segments.error}`,
        videoId,
        title: metadata?.title,
      };
    }

    const typedSegments = segments as TranscriptSegment[];

    // Build transcript text
    let transcript: string;
    if (includeTimestamps) {
      transcript = typedSegments
        .map((s) => `[${formatTimestamp(s.offset / 1000)}] ${s.text}`)
        .join('\n');
    } else {
      transcript = typedSegments.map((s) => s.text).join(' ');
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

    const lastSegment = typedSegments[typedSegments.length - 1];
    const durationSec = lastSegment
      ? Math.ceil((lastSegment.offset + lastSegment.duration) / 1000)
      : 0;

    return {
      videoId,
      title: metadata?.title ?? 'Unknown',
      channel: metadata?.author_name ?? 'Unknown',
      duration: formatTimestamp(durationSec),
      language,
      segmentCount: typedSegments.length,
      transcript,
      truncated,
    };
  },
});
