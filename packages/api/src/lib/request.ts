import { serialize } from "node:v8";

export type RequestKeyArgs<TBody> = {
  path: string;
  method: string;
  body?: TBody;
};

export const getRequestKey = <TBody>({ path, method, body }: RequestKeyArgs<TBody>): string => {
  const serialized = serialize([path, method, body]);
  return serialized.toBase64();
};
