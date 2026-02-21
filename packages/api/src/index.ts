import { Hono } from "hono";
import { proxy } from "hono/proxy";

import type { Env } from "./env";
import { paymentMiddleware } from "./middlewares/payment";
import { badRequest, forbidden, methodNotAllowed, notFound, paymentRequired, unauthorized, unexpectedError } from "./utils/response";

const app = new Hono<Env>();

/* Register routes */
app
  .use("/v1/messages", paymentMiddleware())
  .use("/v1/generation")
  .all((c) =>
    proxy(`${c.env.VERCEL_AI_GATEWAY_BASE_URL}${c.req.path}?${new URLSearchParams(c.req.query()).toString()}`, {
      ...c.req,
      headers: {
        Authorization: `Bearer ${c.env.VERCEL_AI_GATEWAY_API_KEY}`,
        "x-api-key": undefined,
      },
    })
  );

/* Error handling */
app
  /* Not found */
  .get("*", (c) => notFound(c))
  /* Rest */
  .onError((err, c) => {
    console.error(err);

    if ("getResponse" in err) {
      const { status } = err.getResponse();

      switch (status) {
        case 400:
          return badRequest(c, err);
        case 401:
          return unauthorized(c, err);
        case 402:
          return paymentRequired(c, err);
        case 403:
          return forbidden(c, err);
        case 404:
          return notFound(c, err);
        case 405:
          return methodNotAllowed(c, err);
        default:
          return unexpectedError(c);
      }
    }

    return unexpectedError(c);
  });

export default app;
