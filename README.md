# Delta Layer

Delta Layer is a proxy protocol enabling pay-per-request AI inference, integrating x402 for payments and Chainlink Runtime Environment (CRE) for fair settlements. For more on x402, see [docs.x402.org](https://docs.x402.org). Website: [deltalayer.io](https://deltalayer.io).

## Overview

Delta Layer acts as an intermediary between users and AI provider, allowing users to pay exactly for the AI inference they use. It addresses the limitation of x402's exact payment schema by using upfront escrow payments and post-request refunds via CRE arbitration.

## Features

- **Pay-Per-Request with x402**: Users pay upfront based on estimates, with refunds for overpayments.
- **Streaming Support**: Real-time AI responses without delaying payments.
- **Decentralized Settlement**: CRE acts as a neutral arbiter to verify and execute refunds.
- **Escrow-Based Security**: Funds are held in an on-chain escrow contract until settlement.

## How It Works

Delta Layer's workflow combines x402 for secure, upfront payments with CRE for verifiable post-inference settlements. Here's a step-by-step breakdown:

1. **User Initiates Request**:
   - The user sends an API request to Delta Layer.
   - Delta Layer calculates an estimated price based on input tokens and the capped maximum output tokens. This estimate represents the maximum possible cost.

2. **Payment Challenge with x402**:
   - Delta Layer responds with an HTTP 402 status code, including the estimated price and payment instructions.
   - The user pays the exact estimated amount using x402, depositing funds into an on-chain escrow contract. This escrow holds the payment securely until the request is completed and settled.

3. **Payment Settlement and Inference Execution**:
   - The request is forwarded to the AI provider.
   - The AI inference runs, supporting streaming for real-time responses. The user receives the output (streamed or complete) directly.

4. **Post-Request Settlement Initiation**:
   - After the inference completes, Delta Layer sends a settlement request to CRE, including the provider generation id and payment details.

5. **CRE Arbitration and Refund Execution**:
   - CRE triggers a decentralized workflow upon receiving the settlement request (via an HTTP trigger).
   - CRE fetches the actual usage data from the AI provider.
   - CRE nodes reach Byzantine Fault Tolerant (BFT) consensus on the actual cost, ensuring tamper-proof verification.
   - CRE computes the refund: `refund = upfront_payment - actual_cost`.
   - CRE generates a signed report and submits it to the escrow contract via a Keystone Forwarder. This calls the escrow's settlement function to:
     - Transfer the actual cost to the protocol's address.
     - Refund the remainder to the user's address.
   - The escrow validates and executing the transfers atomically.

This process ensures trustless operation: users avoid overpaying for variable AI usage, while the protocol receives exact compensation. Edge cases like failed inferences or timeouts can trigger full refunds via CRE, maintaining fairness.

## Sequence Diagram

The following Mermaid diagram illustrates the end-to-end workflow:

```mermaid
sequenceDiagram
    participant User
    participant API as Protocol API
    participant Escrow as Escrow Contract (EVM)
    participant LLM as LLM Provider (Vercel AI Gateway)
    participant CRE as Chainlink Runtime Environment (CRE)

    Note over User,API: Step 1: User initiates AI inference request
    User->>API: Send API request for AI inference (e.g., prompt, max_tokens)

    Note over API: Calculate estimated price based on input tokens and max_tokens cap
    API->>User: Return 402 status code with estimated price

    Note over User,Escrow: Step 3: User makes upfront payment using x402
    User->>Escrow: Pay exact estimated amount to escrow (via x402 protocol)

    Note over Escrow,API: Payment settlement and confirmation
    Escrow-->>API: Payment confirmed (e.g., via event or query)

    Note over API,LLM: Step 4: Run LLM inference
    API->>LLM: Forward request to LLM (supports streaming)
    LLM-->>API: Stream response (or full response if not streaming)
    API-->>User: Stream/return LLM output to user

    Note over API,CRE: Step 5: Post-request settlement
    API->>CRE: Send settlement request (HTTP trigger: generation ID, escrow details, user address)

    Note over CRE: CRE workflow triggered (decentralized execution across DON)
    Note over CRE,LLM: Step 6: Fetch actual usage data
    CRE->>LLM: GET /generation?id={ID} to retrieve actual token count and cost
    LLM-->>CRE: Return actual cost data

    Note over CRE: Compute refund: actual_cost = based on fetched data<br/>refund = paid - actual_cost<br/>Reach consensus via DON (BFT)

    Note over CRE,Escrow: Execute on-chain settlement
    CRE->>Escrow: Call escrow function (EVM write):<br/>- Transfer actual_cost to protocol<br/>- Refund remainder to user<br/>(via signed report and Keystone Forwarder)

    Note over Escrow: Validate signatures, execute transfers (prevents replays)
    Escrow-->>User: Refund transferred
    Escrow-->>API: Actual cost transferred to protocol

    Note over User,CRE: Process complete; user gets refund if overpaid
```
