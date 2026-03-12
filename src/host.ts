#!/usr/bin/env node

/**
 * Claude Native Messaging Host
 *
 * Platform behavior:
 * - Linux: Direct Claude API mode (reads API key from config file)
 * - macOS/Windows: Passthrough to Claude Desktop's native host binary
 */

import { readMessage, writeMessage } from "./protocol";
import { loadConfig, ConfigError, type HostConfig } from "./config";
import { sendMessage } from "./api-client";
import { findDesktopBinary, startPassthrough } from "./passthrough";

type Mode = "api" | "passthrough";

interface IncomingMessage {
  type?: string;
  content?: string;
  text?: string;
  message?: string;
  messages?: Array<{ role: "user" | "assistant"; content: string }>;
  system?: string;
  [key: string]: unknown;
}

function detectMode(): Mode {
  if (process.platform === "linux") {
    // On Linux, prefer direct API mode (Claude Desktop rarely available)
    const desktopBinary = findDesktopBinary();
    if (desktopBinary) {
      return "passthrough";
    }
    return "api";
  }
  // macOS/Windows: prefer passthrough to Claude Desktop
  return "passthrough";
}

function sendError(message: string): void {
  writeMessage(process.stdout, {
    type: "error",
    error: message,
  });
}

/** Extract the user message text from various possible message formats. */
function extractUserText(msg: IncomingMessage): string | null {
  if (typeof msg.content === "string") return msg.content;
  if (typeof msg.text === "string") return msg.text;
  if (typeof msg.message === "string") return msg.message;
  return null;
}

async function runApiMode(): Promise<void> {
  let config: HostConfig;
  try {
    config = loadConfig();
  } catch (err) {
    if (err instanceof ConfigError) {
      sendError(err.message);
    } else {
      sendError(`Failed to load config: ${err}`);
    }
    process.exit(1);
  }

  // Message loop: read messages from browser, respond via API
  while (true) {
    let msg: unknown;
    try {
      msg = await readMessage(process.stdin);
    } catch (err) {
      // Read error usually means connection closed
      process.stderr.write(`Read error: ${err}\n`);
      break;
    }

    // null = EOF, connection closed
    if (msg === null) break;

    if (typeof msg !== "object" || msg === null) {
      sendError("Invalid message format: expected JSON object");
      continue;
    }

    const incoming = msg as IncomingMessage;

    // Handle ping/health check
    if (incoming.type === "ping") {
      writeMessage(process.stdout, {
        type: "pong",
        mode: "api",
        platform: process.platform,
      });
      continue;
    }

    // Extract message text
    const userText = extractUserText(incoming);
    if (!userText) {
      sendError(
        'Message must contain "content", "text", or "message" field with the user text'
      );
      continue;
    }

    try {
      const response = await sendMessage(
        config,
        userText,
        incoming.messages,
        incoming.system as string | undefined
      );

      writeMessage(process.stdout, {
        type: "response",
        content: response,
      });
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      sendError(`API request failed: ${errMsg}`);
    }
  }
}

function runPassthroughMode(): void {
  const binaryPath = findDesktopBinary();
  if (!binaryPath) {
    // On macOS/Windows without Claude Desktop, provide helpful error
    sendError(
      "Claude Desktop not found. Install Claude Desktop from https://claude.ai/download " +
        "or switch to Linux for direct API mode."
    );
    process.exit(1);
  }
  startPassthrough(binaryPath);
}

function main(): void {
  const mode = detectMode();

  if (mode === "api") {
    runApiMode().catch((err) => {
      process.stderr.write(`Fatal error: ${err}\n`);
      process.exit(1);
    });
  } else {
    runPassthroughMode();
  }
}

main();
