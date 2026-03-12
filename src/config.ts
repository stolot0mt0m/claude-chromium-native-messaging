import * as fs from "fs";
import * as path from "path";
import * as os from "os";

export interface HostConfig {
  apiKey: string;
  model?: string;
}

function getConfigDir(): string {
  if (process.platform === "linux") {
    return (
      process.env.XDG_CONFIG_HOME ||
      path.join(os.homedir(), ".config")
    );
  }
  // macOS: ~/Library/Application Support
  if (process.platform === "darwin") {
    return path.join(os.homedir(), "Library", "Application Support");
  }
  // Windows: %APPDATA%
  return process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming");
}

export function getConfigPath(): string {
  return path.join(
    getConfigDir(),
    "claude-chromium-native-messaging",
    "config.json"
  );
}

export function loadConfig(): HostConfig {
  const configPath = getConfigPath();

  if (!fs.existsSync(configPath)) {
    throw new ConfigError(
      `Config file not found: ${configPath}\n` +
        "Run the install script to set up the native messaging host:\n" +
        "  ./setup.sh\n\n" +
        `Or create the config manually:\n` +
        `  mkdir -p "$(dirname '${configPath}')"\n` +
        `  echo '{"apiKey":"sk-ant-..."}' > '${configPath}'\n` +
        `  chmod 600 '${configPath}'`
    );
  }

  let raw: string;
  try {
    raw = fs.readFileSync(configPath, "utf-8");
  } catch (err) {
    throw new ConfigError(`Cannot read config file: ${configPath}: ${err}`);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ConfigError(`Invalid JSON in config file: ${configPath}`);
  }

  if (
    typeof parsed !== "object" ||
    parsed === null ||
    !("apiKey" in parsed) ||
    typeof (parsed as Record<string, unknown>).apiKey !== "string"
  ) {
    throw new ConfigError(
      `Config must contain "apiKey" (string). File: ${configPath}`
    );
  }

  const config = parsed as Record<string, unknown>;
  return {
    apiKey: config.apiKey as string,
    model: typeof config.model === "string" ? config.model : undefined,
  };
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}
