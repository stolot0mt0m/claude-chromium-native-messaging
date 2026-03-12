/**
 * Chrome Native Messaging protocol: 4-byte little-endian length prefix + JSON payload.
 * https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging#native-messaging-host-protocol
 */

const MAX_MESSAGE_SIZE = 1024 * 1024; // 1 MB Chrome limit

export function readMessage(stdin: NodeJS.ReadStream): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const headerBuf: Buffer[] = [];
    let headerLen = 0;

    const onReadable = (): void => {
      // Phase 1: read 4-byte length header
      while (headerLen < 4) {
        const chunk: Buffer | null = stdin.read(4 - headerLen);
        if (chunk === null) return; // wait for more data
        headerBuf.push(chunk);
        headerLen += chunk.length;
      }

      const header = Buffer.concat(headerBuf);
      const messageLen = header.readUInt32LE(0);

      if (messageLen === 0) {
        cleanup();
        resolve(null);
        return;
      }

      if (messageLen > MAX_MESSAGE_SIZE) {
        cleanup();
        reject(new Error(`Message too large: ${messageLen} bytes (max ${MAX_MESSAGE_SIZE})`));
        return;
      }

      // Phase 2: read JSON payload
      const bodyBuf: Buffer[] = [];
      let bodyLen = 0;

      const readBody = (): void => {
        while (bodyLen < messageLen) {
          const chunk: Buffer | null = stdin.read(messageLen - bodyLen);
          if (chunk === null) return; // wait for more data
          bodyBuf.push(chunk);
          bodyLen += chunk.length;
        }

        cleanup();
        const body = Buffer.concat(bodyBuf).toString("utf-8");
        try {
          resolve(JSON.parse(body));
        } catch {
          reject(new Error(`Invalid JSON in message: ${body.slice(0, 200)}`));
        }
      };

      // Remove the header listener, attach body listener
      stdin.removeListener("readable", onReadable);
      stdin.on("readable", readBody);
      readBody();
    };

    const onEnd = (): void => {
      cleanup();
      resolve(null); // EOF = connection closed
    };

    const onError = (err: Error): void => {
      cleanup();
      reject(err);
    };

    const cleanup = (): void => {
      stdin.removeListener("readable", onReadable);
      stdin.removeListener("end", onEnd);
      stdin.removeListener("error", onError);
    };

    stdin.on("readable", onReadable);
    stdin.on("end", onEnd);
    stdin.on("error", onError);
  });
}

export function writeMessage(stdout: NodeJS.WriteStream, data: unknown): void {
  const json = JSON.stringify(data);
  const body = Buffer.from(json, "utf-8");

  if (body.length > MAX_MESSAGE_SIZE) {
    throw new Error(`Response too large: ${body.length} bytes (max ${MAX_MESSAGE_SIZE})`);
  }

  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);

  stdout.write(header);
  stdout.write(body);
}
