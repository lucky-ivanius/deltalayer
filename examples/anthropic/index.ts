import { x402Client, x402HTTPClient } from "@x402/core/client";
import { registerExactEvmScheme } from "@x402/evm/exact/client";
import { wrapFetchWithPayment } from "@x402/fetch";
import { privateKeyToAccount } from "viem/accounts";

// Create signer
const signer = privateKeyToAccount(process.env.EVM_PRIVATE_KEY as `0x${string}`);

const baseUrl = process.env.BASE_URL || "http://localhost:8787";
const path = "/v1/messages";

// Create x402 client and register EVM scheme
const client = new x402Client();
registerExactEvmScheme(client, { signer });

// Wrap fetch with payment handling
const fetchWithPayment = wrapFetchWithPayment(fetch, client);

// Make request - payment is handled automatically
const model = "anthropic/claude-haiku-4.5";
const messages = [
  {
    role: "user",
    content: "Write a one-sentence bedtime story",
  },
];

const response = await fetchWithPayment(`${baseUrl}${path}`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    model,
    max_tokens: 150,
    messages,
  }),
});

const data = await response.json();
console.log("Response:", data);

if (response.ok) {
  const httpClient = new x402HTTPClient(client);
  const paymentResponse = httpClient.getPaymentSettleResponse((name) => response.headers.get(name));
  console.log("Payment settled:", paymentResponse);
}
