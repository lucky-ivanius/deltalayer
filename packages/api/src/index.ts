import { Hono } from "hono";
import { proxy } from "hono/proxy";

import type { Env } from "./env";
import { paymentMiddleware } from "./middlewares/payment";
import { unexpectedError } from "./utils/response";

const app = new Hono<Env>();

/* Register routes */
app
  .use(
    "/v1/messages",
    paymentMiddleware(() => Math.random() * 0.01)
  )
  .use("/v1/generation")
  .all((c) =>
    proxy(`${c.env.VERCEL_AI_GATEWAY_BASE_URL}${c.req.path}?${new URLSearchParams(c.req.query()).toString()}`, {
      ...c.req,
      headers: {
        ...c.req.header(),
        Authorization: `Bearer ${c.env.VERCEL_AI_GATEWAY_API_KEY}`,
        "x-api-key": undefined,
      },
    })
  );

/* Error handling */
app
  /* Rest */
  .onError((err, c) => {
    console.error(err);

    return unexpectedError(c);
  });

export default app;
