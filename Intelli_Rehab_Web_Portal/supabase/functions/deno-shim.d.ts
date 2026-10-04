// Editor-only stand-in for the parts of the Deno runtime the functions use.
declare namespace Deno {
  function serve(handler: (req: Request) => Response | Promise<Response>): void;
  const env: { get(key: string): string | undefined };
}
