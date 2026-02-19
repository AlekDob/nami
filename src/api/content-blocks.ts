import type { ContentBlock } from './types.js';

interface ToolCall {
  toolName: string;
  args: unknown;
  result?: unknown;
}

const TWEET_TOOLS = new Set([
  'xBrowseTimeline',
  'xBrowseProfile',
  'xBrowseSearch',
  'xGetTimeline',
  'xSearchTweets',
  'xGetMentions',
]);

export function extractContentBlocks(toolCalls: ToolCall[]): ContentBlock[] {
  const blocks: ContentBlock[] = [];

  for (const call of toolCalls) {
    if (TWEET_TOOLS.has(call.toolName) && call.result) {
      const tweetBlocks = extractTweetBlocks(call.result);
      blocks.push(...tweetBlocks);
    }
  }

  return blocks;
}

function extractTweetBlocks(result: unknown): ContentBlock[] {
  const blocks: ContentBlock[] = [];
  const data = result as Record<string, unknown>;
  const tweets = (data.tweets || data.mentions) as
    | Array<Record<string, string | boolean | string[]>>
    | undefined;

  if (!Array.isArray(tweets)) return blocks;

  for (const tweet of tweets) {
    blocks.push({
      type: 'tweet',
      data: {
        text: String(tweet.text || ''),
        author: String(tweet.author || ''),
        handle: String(tweet.handle || ''),
        avatar: String(tweet.avatar || ''),
        time: String(tweet.time || ''),
        likes: String(tweet.likes || '0'),
        retweets: String(tweet.retweets || '0'),
        replies: String(tweet.replies || '0'),
        url: String(tweet.url || ''),
        isVerified: Boolean(tweet.isVerified),
        images: Array.isArray(tweet.images) ? tweet.images.map(String) : [],
      },
    });
  }

  return blocks;
}
