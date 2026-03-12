import { spawn, ChildProcess } from "child_process";
import * as fs from "fs";

/**
 * On macOS/Windows, delegate to the existing Claude Desktop native host binary.
 * Spawns the binary and pipes stdin/stdout through.
 */
export function startPassthrough(binaryPath: string): void {
  if (!fs.existsSync(binaryPath)) {
    process.stderr.write(
      `Claude Desktop native host not found: ${binaryPath}\n`
    );
    process.exit(1);
  }

  const child: ChildProcess = spawn(binaryPath, [], {
    stdio: ["pipe", "pipe", "inherit"],
  });

  // Pipe browser stdin → child stdin
  process.stdin.pipe(child.stdin!);

  // Pipe child stdout → browser stdout
  child.stdout!.pipe(process.stdout);

  child.on("exit", (code) => {
    process.exit(code ?? 0);
  });

  child.on("error", (err) => {
    process.stderr.write(`Failed to spawn native host: ${err.message}\n`);
    process.exit(1);
  });

  // If browser closes stdin, also close the child
  process.stdin.on("end", () => {
    child.stdin!.end();
  });
}

/** Find the Claude Desktop native host binary for the current platform. */
export function findDesktopBinary(): string | null {
  const paths = getDesktopBinaryPaths();
  for (const p of paths) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function getDesktopBinaryPaths(): string[] {
  if (process.platform === "darwin") {
    return [
      "/Applications/Claude.app/Contents/Helpers/chrome-native-host",
    ];
  }

  if (process.platform === "win32") {
    const localAppData = process.env.LOCALAPPDATA || "";
    const programFiles = process.env.PROGRAMFILES || "";
    const programFilesX86 = process.env["PROGRAMFILES(X86)"] || "";
    const appData = process.env.APPDATA || "";
    return [
      `${appData}\\Claude\\ChromeNativeHost\\chrome-native-host.exe`,
      `${localAppData}\\Programs\\claude\\resources\\chrome-native-host.exe`,
      `${localAppData}\\Claude\\chrome-native-host.exe`,
      `${programFiles}\\Claude\\chrome-native-host.exe`,
      `${programFilesX86}\\Claude\\chrome-native-host.exe`,
    ];
  }

  // Linux: Claude Desktop paths (speculative, may not exist)
  const home = process.env.HOME || "";
  return [
    "/opt/Claude/chrome-native-host",
    "/usr/lib/claude/chrome-native-host",
    `${home}/.local/share/Claude/chrome-native-host`,
    "/snap/claude/current/chrome-native-host",
    `${home}/.var/app/ai.anthropic.claude/chrome-native-host`,
  ];
}
