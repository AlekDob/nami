# Model Providers Configuration

How to configure direct API providers for NamiOS. Each provider bypasses OpenRouter for lower latency and direct billing.

## Z.AI (GLM Models)

**Base URL**: `https://api.z.ai/api/coding/paas/v4`
**Protocol**: OpenAI-compatible (Chat Completions API)
**Env var**: `ZAI_API_KEY`

### Available Models

| Model ID | Tier | Tool Use | Vision | Notes |
|----------|------|----------|--------|-------|
| `glm-5` | pro | Yes | No | 744B params, requires upgraded plan |
| `glm-4.7` | smart | Yes | No | Default model, best balance |
| `glm-4.7-flash` | fast | Yes | No | Faster, cheaper |
| `glm-4.5v` | smart | No | **Yes** | Vision model, 106B params |

### Configuration in `src/config/models.ts`

```typescript
if (entry.provider === 'zai') {
  const provider = createOpenAI({
    baseURL: 'https://api.z.ai/api/coding/paas/v4',
    apiKey,
    name: 'zai',
  });
  return provider.chat(entry.id);
}
```

### Important Notes

- The endpoint is `/api/coding/paas/v4` (coding variant), NOT `/api/paas/v4`
- GLM-4.7 does NOT support image input — use GLM-4.5V or GLM-4.6V for vision (via OpenRouter, different endpoint)
- The API key format is `{key_id}.{secret}` (e.g., `06db06...pN1D3E...`)
- Get your key at: https://open.bigmodel.cn/ (Z.AI platform)

---

## MiniMax (M2.1 / M2.5 Models)

**Base URL**: `https://api.minimax.io/v1`
**Protocol**: OpenAI-compatible (Chat Completions API)
**Env var**: `MINIMAX_API_KEY`

### Available Models

| Model ID | Tier | Tool Use | Vision | Notes |
|----------|------|----------|--------|-------|
| `MiniMax-M2.5` | smart | Yes | No | Best quality, 50 tok/s |
| `MiniMax-M2.5-highspeed` | fast | Yes | No | Lightning variant, 100 tok/s |
| `MiniMax-M2.1` | smart | Yes | No | Previous gen |
| `MiniMax-M2.1-highspeed` | fast | Yes | No | Previous gen, faster |

### Configuration in `src/config/models.ts`

```typescript
if (entry.provider === 'minimax') {
  const provider = createOpenAI({
    baseURL: 'https://api.minimax.io/v1',
    apiKey,
    name: 'minimax',
  });
  return provider.chat(entry.id);
}
```

### Important Notes

- MiniMax exposes BOTH OpenAI (`/v1`) and Anthropic (`/anthropic`) endpoints — we use OpenAI because the Anthropic endpoint returns 404 with `@ai-sdk/anthropic` (path mismatch on `/messages`)
- For Cursor/other IDE clients, the Anthropic endpoint (`/anthropic`) works because those clients handle the path differently
- M2.5 emits `<think>...</think>` reasoning tags — these are stripped server-side in `agent.ts` before sending to clients
- M2.5 and M2.1 are **text-only** — NO vision/image support (despite Cursor config showing `noImageSupport: false`)
- API key format: `sk-cp-...` (starts with `sk-cp-`)
- Get your key at: https://platform.minimax.io/
- Pricing: M2.5-highspeed ~$0.3/M input, ~$2.4/M output

### `<think>` Tag Stripping

MiniMax M2.5 includes chain-of-thought reasoning wrapped in `<think>` tags. This is stripped in `src/agent/agent.ts`:

```typescript
const text = result.text.replace(/<think>[\s\S]*?<\/think>\s*/g, '');
```

This applies globally to all models (harmless for models that don't emit these tags).

---

## Adding a New Provider

1. Add provider name to `ProviderName` type union
2. Add env var to `DetectedKeys` interface and `detectApiKeys()`
3. Add `isAvailable()` check
4. Add `getApiKey()` case
5. Add `createModel()` block with correct SDK (`createOpenAI` or `createAnthropic`)
6. Add model entries to `REGISTRY` with correct `provider`, `preset`, `toolUse`, `vision`
7. Deploy to server: `scp src/config/models.ts root@ubuntu-4gb-hel1-1:/root/meow/src/config/models.ts`
8. Add API key to server `.env`: `ssh root@ubuntu-4gb-hel1-1 'echo "NEW_API_KEY=xxx" >> /root/meow/.env'`
9. Restart: `ssh root@ubuntu-4gb-hel1-1 'systemctl restart nami'`

---

## Server `.env` Reference

```bash
# Required for each direct provider
ZAI_API_KEY=06db0...pN1D3E...
MINIMAX_API_KEY=sk-cp-...
OPENAI_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
MOONSHOT_API_KEY=...
```

## Last Updated
2026-02-16
