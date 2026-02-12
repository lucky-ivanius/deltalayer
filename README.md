# Delta Layer

**Pay-per-request for AI APIs. No subscriptions, no prepaid credits.**

Delta Layer is a payment layer for OpenAI, Anthropic, Gemini, and other LLM providers. Pay only for what you use with USDC, with instant settlement powered by x402.

## Why Delta Layer?

- **True pay-per-request**: No monthly commitments or minimum balances
- **Fast settlement**: Powered by x402 protocol
- **Drop-in replacement**: Works with your existing AI libraries (Vercel AI, LangChain, etc.)
- **Unified billing**: One wallet for all LLM providers

## Quick Start

Use your wallet:

```ts
import { generateText } from 'ai';
import { createOpenAI } from '@deltalayer/vercel-ai';
import { createWalletClient } from 'viem';

const walletClient = createWalletClient({
  account: yourAccount,
  chain: base,
  transport: http()
});

const openai = createOpenAI({
  walletClient, // or use `apiKey: process.env.DELTALAYER_API_KEY`
});

const { text } = await generateText({
  model: openai("gpt-4o"),
  prompt: "Hello world"
});
```

## How It Works

1. Routes your requests through `https://routes.deltalayer.io/{provider}/...`
2. Estimates cost upfront using x402 payment protocol
3. Executes your request to the LLM provider
4. Automatically refunds any overpayment via Chainlink Runtime Environment

## Supported Providers

- OpenAI
- Anthropic
- Google Gemini
- And more

---

**Website**: [deltalayer.io](https://deltalayer.io)
