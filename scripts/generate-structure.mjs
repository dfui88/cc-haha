/**
 * 项目目录结构自动生成脚本
 *
 * 用法: node scripts/generate-structure.mjs [目录路径] [选项]
 *
 * 选项:
 *   --depth <n>      最大递归深度 (默认: 3)
 *   --no-gitignore   不读取 .gitignore
 *   --output <file>  输出到文件
 *
 * 示例:
 *   node scripts/generate-structure.mjs
 *   node scripts/generate-structure.mjs src --depth 4
 *   node scripts/generate-structure.mjs desktop/src --depth 2
 */

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

// ── 解析命令行参数 ────────────────────────────────────────
const args = process.argv.slice(2);
const depthIdx = args.indexOf('--depth');
const maxDepth = depthIdx !== -1 ? parseInt(args[depthIdx + 1], 10) : 5;
const noGitignore = args.includes('--no-gitignore');
const outputIdx = args.indexOf('--output');
const outputFile = outputIdx !== -1 ? args[outputIdx + 1] : null;

// 移除已知 flag 及其值，剩下的第一个非 flag 参数作为目标目录
const knownFlags = new Set(['--depth', '--no-gitignore', '--output']);
let targetDir = ROOT;
for (let i = 0; i < args.length; i++) {
  if (knownFlags.has(args[i])) {
    if (args[i] === '--depth' || args[i] === '--output') i++; // 跳过值
    continue;
  }
  // 不跳过 flags
  if (args[i].startsWith('--')) continue;
  targetDir = args[i];
  break;
}

// ── 加载 ignore 库 ────────────────────────────────────────
const require = createRequire(import.meta.url);
const Ignore = require('ignore');

// ── 读取 .gitignore ──────────────────────────────────────
const gitignorePath = path.join(targetDir, '.gitignore');
const ig = Ignore();
ig.add([
  'node_modules',
  '.git',
  '.claude',
  '.DS_Store',
  '*.tsbuildinfo',
  '.runtime/',
  'extracted-natives/',
  '.lark-attachments/',
  '.tg-attachments/',
  '.playwright-mcp/',
  '.omx/',
  'dist/',
  'build-artifacts/',
  'target/',
  'binaries/',
  'gen/',
  '__pycache__',
  '*.png',
  '*.pem',
  '*.key',
  '*.p12',
  '*.lock',
]);

if (!noGitignore && fs.existsSync(gitignorePath)) {
  const gitignoreContent = fs.readFileSync(gitignorePath, 'utf-8');
  ig.add(gitignoreContent);
}

// ── 额外的排除规则 ────────────────────────────────────────
const ALWAYS_IGNORE = [
  'node_modules',
  '.git',
  '.claude',
  '__pycache__',
  '*.tsbuildinfo',
  'package-lock.json',
  'bun.lock',
  '.lark-attachments',
  '.tg-attachments',
  '.playwright-mcp',
  '.omx',
];

// ── 判断是否应该忽略 ────────────────────────────────────
function shouldIgnore(relativePath, isDir) {
  if (isDir) relativePath += '/';

  // 先检查 always_ignore（精确匹配目录名或文件名）
  for (const pattern of ALWAYS_IGNORE) {
    const isGlob = pattern.includes('*');
    if (isGlob) {
      // 简单 glob 匹配文件名
      const regex = new RegExp('^' + pattern.replace(/\*/g, '.*').replace(/\./g, '\\.') + '$');
      if (regex.test(path.basename(relativePath.replace(/\/$/, '')))) return true;
    } else if (path.basename(relativePath.replace(/\/$/, '')) === pattern) {
      return true;
    }
  }

  return ig.ignores(relativePath);
}

// ── 收集目录树 ──────────────────────────────────────────
function collectTree(dir, depth = 0) {
  if (depth > maxDepth) return null;

  const entries = [];
  let items;

  try {
    items = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return null;
  }

  // 排序：目录在前，文件在后，各自按字母排序
  items.sort((a, b) => {
    if (a.isDirectory() !== b.isDirectory()) {
      return a.isDirectory() ? -1 : 1;
    }
    return a.name.localeCompare(b.name);
  });

  for (const item of items) {
    const relativePath = path.relative(targetDir, path.join(dir, item.name));
    const relativePosix = relativePath.replace(/\\/g, '/');

    if (shouldIgnore(relativePosix, item.isDirectory())) continue;

    // 跳过包含 "fixtures" 的测试数据目录（减少噪音）
    if (item.isDirectory() && item.name === 'fixtures' && depth > 1) continue;

    if (item.isDirectory()) {
      const subTree = collectTree(path.join(dir, item.name), depth + 1);
      if (subTree) {
        entries.push({ name: item.name, type: 'dir', children: subTree });
      } else {
        // 目录超过深度但本身不应忽略，标记为...
        entries.push({ name: item.name + '/', type: 'dir-short' });
      }
    } else {
      // 只保留特定扩展名的文件来减少噪音
      const ext = path.extname(item.name).toLowerCase();
      const summaryExts = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.json', '.css', '.html', '.rs', '.toml'];
      const isSummary = summaryExts.includes(ext) ||
        ['package.json', 'tsconfig.json', 'vite.config.ts', 'vitest.config.ts'].includes(item.name);

      entries.push({
        name: item.name,
        type: 'file',
        isSummary: isSummary || depth <= 1,
      });
    }
  }

  return entries;
}

// ── 渲染树 ──────────────────────────────────────────────
function renderTree(entries, prefix = '') {
  let output = '';

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const isLast = i === entries.length - 1;
    const connector = isLast ? '└── ' : '├── ';
    const childPrefix = isLast ? '    ' : '│   ';

    if (entry.type === 'dir') {
      output += prefix + connector + entry.name + '/' + '\n';
      output += renderTree(entry.children, prefix + childPrefix);
    } else if (entry.type === 'dir-short') {
      output += prefix + connector + entry.name + '\n';
    } else if (entry.isSummary) {
      output += prefix + connector + entry.name + '\n';
    }
    // 非摘要文件跳过
  }

  return output;
}

// ── 渲染摘要树（排除细节文件） ────────────────────────
function renderSummary(entries, prefix = '', showFiles = false) {
  let output = '';

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const isLast = i === entries.length - 1;
    const connector = isLast ? '└── ' : '├── ';
    const childPrefix = isLast ? '    ' : '│   ';

    if (entry.type === 'dir') {
      output += prefix + connector + entry.name + '/' + '\n';
      output += renderSummary(entry.children, prefix + childPrefix, showFiles);
    } else if (entry.type === 'dir-short') {
      output += prefix + connector + entry.name + '\n';
    } else if (showFiles) {
      output += prefix + connector + entry.name + '\n';
    }
  }

  return output;
}

// ── 解析目标目录（支持相对路径） ───────────────────────
function parseTarget(input) {
  // 如果是针对根目录下的子路径
  const candidate = path.resolve(ROOT, input);
  if (fs.existsSync(candidate)) return candidate;

  // 原始输入（可能是绝对路径）
  if (fs.existsSync(input)) return path.resolve(input);

  console.error(`目录不存在: ${input}`);
  process.exit(1);
}

// ── 主函数 ──────────────────────────────────────────────
function main() {
  const resolvedTarget = parseTarget(targetDir);
  const relPath = path.relative(ROOT, resolvedTarget) || '.';

  console.error(`扫描目录: ${resolvedTarget}`);
  console.error(`深度限制: ${maxDepth}`);
  console.error('');

  const tree = collectTree(resolvedTarget);
  if (!tree) {
    console.error('无法读取目录');
    process.exit(1);
  }

  const isRoot = relPath === '.';
  const header = isRoot
    ? '# 项目目录结构\n\n> 由 \`scripts/generate-structure.mjs\` 自动生成，运行 \`npm run generate:structure\` 更新\n'
    : `# ${relPath} 目录结构\n`;

  const treeText = header + '\n```\n' + relPath + '/\n' + renderTree(tree) + '```\n';

  if (outputFile) {
    const outputPath = path.resolve(ROOT, outputFile);
    fs.writeFileSync(outputPath, treeText, 'utf-8');
    console.error(`已写入: ${outputPath}`);
  } else {
    console.log(treeText);
  }
}

main();
