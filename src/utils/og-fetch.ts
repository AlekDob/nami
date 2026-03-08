/**
 * Fetch Open Graph metadata from a URL.
 * Extracts og:image, og:title, og:description from HTML <meta> tags.
 */

export interface OgMetadata {
  ogImage?: string;
  ogTitle?: string;
  ogDescription?: string;
}

export async function fetchOgMetadata(url: string): Promise<OgMetadata> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; NamiBot/1.0)',
        'Accept': 'text/html',
      },
      redirect: 'follow',
    });
    clearTimeout(timeout);

    if (!response.ok) return {};

    // Only read first 50KB to avoid downloading huge pages
    const reader = response.body?.getReader();
    if (!reader) return {};

    let html = '';
    const decoder = new TextDecoder();
    while (html.length < 50_000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += decoder.decode(value, { stream: true });
      // Stop early if we've passed </head>
      if (html.includes('</head>')) break;
    }
    reader.cancel().catch(() => {});

    return parseOgTags(html);
  } catch {
    return {};
  }
}

function parseOgTags(html: string): OgMetadata {
  const result: OgMetadata = {};

  const metaRegex = /<meta\s[^>]*>/gi;
  let match: RegExpExecArray | null;

  while ((match = metaRegex.exec(html)) !== null) {
    const tag = match[0];
    const property = extractAttr(tag, 'property') || extractAttr(tag, 'name');
    const content = extractAttr(tag, 'content');
    if (!property || !content) continue;

    switch (property.toLowerCase()) {
      case 'og:image':
        result.ogImage = content;
        break;
      case 'og:title':
        result.ogTitle = content;
        break;
      case 'og:description':
        result.ogDescription = content;
        break;
    }
  }

  return result;
}

function extractAttr(tag: string, attr: string): string | undefined {
  // Match attr="value" or attr='value'
  const regex = new RegExp(`${attr}\\s*=\\s*["']([^"']+)["']`, 'i');
  const match = tag.match(regex);
  return match?.[1];
}
