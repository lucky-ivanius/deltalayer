import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";

import type { Env } from "./env";
import { badRequest, forbidden, methodNotAllowed, notFound, paymentRequired, unauthorized, unexpectedError } from "./utils/response";

const app = new Hono<Env>();

/* Register middlewares */
app.use(logger()).use(cors());

app
  /* Not found */
  .get("*", (c) => notFound(c))
  /* Handle errors */
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
