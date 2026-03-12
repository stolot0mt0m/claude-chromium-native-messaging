import * as https from "https";
import type { HostConfig } from "./config";

const API_HOST = "api.anthropic.com";
const API_PATH = "/v1/messages";
const API_VERSION = "2023-06-01";
const DEFAULT_MODEL = "claude-sonnet-4-20250514";
const DEFAULT_MAX_TOKENS = 4096;

interface ApiMessage {
  role: "user" | "assistant";
  content: string;
}

interface ApiRequest {
  model: string;
  max_tokens: number;
  messages: ApiMessage[];
  system?: string;
}

interface ApiContentBlock {
  type: string;
  text?: string;
}

interface ApiResponse {
  id: string;
  type: string;
  role: string;
  content: ApiContentBlock[];
  model: string;
  stop_reason: string | null;
  usage: { input_tokens: number; output_tokens: number };
}

interface ApiError {
  type: string;
  error: { type: string; message: string };
}

/** Send a message to the Claude API and return the text response. */
export async function sendMessage(
  config: HostConfig,
  userMessage: string,
  conversationHistory?: ApiMessage[],
  systemPrompt?: string
): Promise<string> {
  const messages: ApiMessage[] = conversationHistory
    ? [...conversationHistory, { role: "user", content: userMessage }]
    : [{ role: "user", content: userMessage }];

  const body: ApiRequest = {
    model: config.model || DEFAULT_MODEL,
    max_tokens: DEFAULT_MAX_TOKENS,
    messages,
  };

  if (systemPrompt) {
    body.system = systemPrompt;
  }

  const responseBody = await httpPost(config.apiKey, body);

  // Check for API error
  if (typeof responseBody === "object" && responseBody !== null && "error" in responseBody) {
    const apiErr = responseBody as ApiError;
    throw new Error(
      `Claude API error (${apiErr.error.type}): ${apiErr.error.message}`
    );
  }

  const apiResp = responseBody as ApiResponse;
  const textBlocks = apiResp.content.filter((b) => b.type === "text");
  return textBlocks.map((b) => b.text || "").join("");
}

function httpPost(apiKey: string, body: ApiRequest): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);

    const options: https.RequestOptions = {
      hostname: API_HOST,
      port: 443,
      path: API_PATH,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": API_VERSION,
        "Content-Length": Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("end", () => {
        const raw = Buffer.concat(chunks).toString("utf-8");
        try {
          resolve(JSON.parse(raw));
        } catch {
          reject(
            new Error(`Invalid JSON from API (HTTP ${res.statusCode}): ${raw.slice(0, 500)}`)
          );
        }
      });
    });

    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}
