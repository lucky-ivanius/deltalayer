export type RequestKeyArgs<TBody> = {
  path: string;
  method: string;
  body?: TBody;
};

export const getRequestKey = <TBody>({ path, method, body }: RequestKeyArgs<TBody>): string => {
  const raw = JSON.stringify([path, method, body]);
  const encoded = new TextEncoder().encode(raw);
  return btoa(String.fromCharCode(...encoded));
};
