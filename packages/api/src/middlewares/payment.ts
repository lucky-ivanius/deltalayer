import { HTTPFacilitatorClient, x402ResourceServer } from "@x402/core/server";
import { registerExactEvmScheme } from "@x402/evm/exact/server";
import { paymentMiddleware as honoPaymentMiddleware } from "@x402/hono";
import { createMiddleware } from "hono/factory";

import type { Env } from "../env";
import { getRequestKey } from "../lib/request";

export type CalculatePrice<TData> = (data: TData) => number | Promise<number>;

export const paymentMiddleware = <TData>(calculatePrice: CalculatePrice<TData>) =>
  createMiddleware<Env>(async (c, next) => {
    const facilitator = new HTTPFacilitatorClient({
      url: c.env.X402_FACILITATOR_URL,
    });

    const server = new x402ResourceServer(facilitator);
    registerExactEvmScheme(server);

    const body = (await c.req.raw
      .clone()
      .json()
      .catch(() => ({}))) as TData;
    const requestKey = getRequestKey({ method: c.req.method, path: c.req.path, body });

    const cachedPrice = await c.env.REQUEST_KV.get(requestKey);
    const price = cachedPrice ? Number(cachedPrice) : await calculatePrice(body);

    const response = honoPaymentMiddleware(
      {
        accepts: {
          scheme: "exact",
          network: "eip155:84532",
          payTo: c.env.X402_WALLET_ADDRESS,
          price: `$${price}`,
        },
      },
      server
    )(c, next);

    await c.env.REQUEST_KV.put(requestKey, price.toString());

    return response;
  });
