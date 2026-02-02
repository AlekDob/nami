import { execSync } from 'child_process';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const PASTE_DIR = join(tmpdir(), 'meow-paste');

let imageCounter = 1000;

function nextImageId(): number {
  return ++imageCounter + Math.floor(Math.random() * 9000);
}

function ensurePasteDir(): void {
  if (!existsSync(PASTE_DIR)) {
    mkdirSync(PASTE_DIR, { recursive: true });
  }
}

/** Check if clipboard contains an image and save it. Returns path or null. */
export function pasteImageFromClipboard(): string | null {
  try {
    if (process.platform === 'darwin') {
      return pasteMacOS();
    }
    if (process.platform === 'linux') {
      return pasteLinux();
    }
    return null;
  } catch {
    return null;
  }
}

function pasteMacOS(): string | null {
  ensurePasteDir();
  const id = nextImageId();
  const outPath = join(PASTE_DIR, `paste-${id}.png`);

  // Write AppleScript to temp file to avoid shell encoding issues
  const scriptPath = join(PASTE_DIR, 'paste.scpt');
  const script = [
    'set imgData to the clipboard as \u00ABclass PNGf\u00BB',
    `set filePath to POSIX file "${outPath}"`,
    'set fileRef to open for access filePath with write permission',
    'write imgData to fileRef',
    'close access fileRef',
  ].join('\n');
  writeFileSync(scriptPath, script, 'utf-8');

  try {
    execSync(`osascript "${scriptPath}"`, {
      timeout: 5000,
      stdio: 'pipe',
    });
  } catch {
    return null;
  }

  return existsSync(outPath) ? outPath : null;
}

function pasteLinux(): string | null {
  // Check clipboard targets for image types
  let targets = '';
  try {
    targets = execSync(
      'xclip -selection clipboard -t TARGETS -o 2>/dev/null',
      { encoding: 'utf-8', timeout: 3000 },
    );
  } catch {
    return null;
  }
  if (!targets.includes('image/png') && !targets.includes('image/jpeg')) {
    return null;
  }

  ensurePasteDir();
  const id = nextImageId();
  const mime = targets.includes('image/png') ? 'image/png' : 'image/jpeg';
  const ext = mime === 'image/png' ? 'png' : 'jpg';
  const outPath = join(PASTE_DIR, `paste-${id}.${ext}`);

  const buf = execSync(
    `xclip -selection clipboard -t ${mime} -o 2>/dev/null`,
    { timeout: 5000 },
  );
  writeFileSync(outPath, buf);

  return existsSync(outPath) ? outPath : null;
}

