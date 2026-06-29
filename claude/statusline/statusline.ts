#!/usr/bin/env -S deno run --allow-read --allow-env --allow-run

// Gruvbox-inspired colors (matches starship.toml palette)
const C = {
  reset: "\x1b[0m",
  reverse: "\x1b[7m",
  orange: "\x1b[38;2;214;93;14m",      // color_orange    #d65d0e
  yellow: "\x1b[38;2;215;153;33m",     // color_yellow    #d79921
  aqua: "\x1b[38;2;104;157;106m",      // color_aqua      #689d6a
  blue: "\x1b[38;2;69;133;136m",       // color_blue      #458588
  red: "\x1b[38;2;204;36;29m",         // color_red       #cc241d
  brightred: "\x1b[38;2;251;73;52m",   // bright red      #fb4934
  dim: "\x1b[38;2;102;92;84m",         // color_bg3       #665c54 (空セル用、見えるくらいに)
  grey: "\x1b[38;2;146;131;116m",      // gruvbox grey    #928374
}

// ---- Gauge config (user-tunable, no model-specific data) -------------------
const CELL_TOKENS = 20_000     // 1 セル = 20K
const BASE_CELLS = 10          // 200K 分の基準ゲージ
const SUBCELL_CHARS = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
const EMPTY_CELL = "░"
const FULL_CELL = "█"

// ---- Helpers ---------------------------------------------------------------

function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
  return n.toString()
}

function baseCellColor(idx: number): string {
  if (idx < 5) return C.aqua    // 0-100K
  if (idx < 7) return C.yellow  // 100-140K
  if (idx < 9) return C.orange  // 140-180K
  return C.red                   // 180-200K
}

function overflowCellColor(idx: number): string {
  // idx = 0-based セル位置 (基準ゲージ外、各 20K)
  if (idx < 10) return C.red                              // 200-400K
  if (idx < 25) return C.brightred                        // 400-700K
  return C.reverse + C.brightred                           // 700K+ (反転表示)
}

function renderGauge(tokens: number, termCols: number): string {
  const fullCells = Math.floor(tokens / CELL_TOKENS)
  const partialFrac = (tokens % CELL_TOKENS) / CELL_TOKENS
  const partialIdx = Math.round(partialFrac * 8)

  const parts: string[] = []

  // ---- Base section (0-200K) ----
  for (let i = 0; i < BASE_CELLS; i++) {
    if (i < fullCells) {
      parts.push(baseCellColor(i) + FULL_CELL + C.reset)
    } else if (i === fullCells && partialIdx > 0) {
      parts.push(baseCellColor(i) + SUBCELL_CHARS[partialIdx] + C.reset)
    } else {
      parts.push(C.dim + EMPTY_CELL + C.reset)
    }
  }

  // ---- Overflow section (200K+) ----
  if (tokens > BASE_CELLS * CELL_TOKENS) {
    parts.push(C.grey + "│" + C.reset)

    const overflowTokens = tokens - BASE_CELLS * CELL_TOKENS
    const overflowFull = Math.floor(overflowTokens / CELL_TOKENS)
    const overflowPartialFrac = (overflowTokens % CELL_TOKENS) / CELL_TOKENS
    const overflowPartialIdx = Math.round(overflowPartialFrac * 8)
    const totalOverflowCells = overflowFull + (overflowPartialIdx > 0 ? 1 : 0)

    // ターミナル幅予算: status の他のブロックで ~70 cols 使う想定
    // overflow に使える幅 = 残り。ただし 200K 以下のゲージは絶対圧縮しない
    const overflowBudget = Math.max(5, termCols - 80)

    if (totalOverflowCells > overflowBudget) {
      // 圧縮: 先頭 N セル + …×M
      const showCount = Math.max(3, overflowBudget - 5)
      for (let i = 0; i < showCount; i++) {
        parts.push(overflowCellColor(i) + FULL_CELL + C.reset)
      }
      const hidden = totalOverflowCells - showCount
      parts.push(C.grey + `…×${hidden}` + C.reset)
    } else {
      for (let i = 0; i < overflowFull; i++) {
        parts.push(overflowCellColor(i) + FULL_CELL + C.reset)
      }
      if (overflowPartialIdx > 0) {
        parts.push(overflowCellColor(overflowFull) + SUBCELL_CHARS[overflowPartialIdx] + C.reset)
      }
    }
  }

  return parts.join("")
}

function tokenLabelColor(tokens: number): string {
  const cellIdx = Math.floor(tokens / CELL_TOKENS)
  if (cellIdx >= BASE_CELLS) return C.brightred
  return baseCellColor(Math.min(cellIdx, BASE_CELLS - 1))
}

async function calculateTokensFromTranscript(filePath: string): Promise<number> {
  try {
    const content = await Deno.readTextFile(filePath)
    const lines = content.trim().split("\n")
    let lastUsage = null
    for (const line of lines) {
      try {
        const entry = JSON.parse(line)
        if (entry.type === "assistant" && entry.message?.usage) {
          lastUsage = entry.message.usage
        }
      } catch {
        // skip
      }
    }
    if (lastUsage) {
      return (
        (lastUsage.input_tokens || 0) +
        (lastUsage.output_tokens || 0) +
        (lastUsage.cache_creation_input_tokens || 0) +
        (lastUsage.cache_read_input_tokens || 0)
      )
    }
    return 0
  } catch {
    return 0
  }
}

function truncatePath(fullPath: string): string {
  const home = Deno.env.get("HOME") || ""
  let path = fullPath
  if (home && path.startsWith(home)) {
    path = "~" + path.slice(home.length)
  }
  const parts = path.startsWith("~/")
    ? ["~", ...path.slice(2).split("/").filter(Boolean)]
    : path.split("/").filter(Boolean)
  if (parts.length <= 3) return path
  return "…/" + parts.slice(-2).join("/")
}

async function getGitBranch(dir: string): Promise<string> {
  try {
    const proc = new Deno.Command("git", {
      args: ["-C", dir, "--no-optional-locks", "branch", "--show-current"],
      stdout: "piped",
      stderr: "null",
    })
    const output = await proc.output()
    return new TextDecoder().decode(output.stdout).trim()
  } catch {
    return ""
  }
}

async function getGitDirty(dir: string): Promise<boolean> {
  try {
    const proc = new Deno.Command("git", {
      args: ["-C", dir, "--no-optional-locks", "status", "--porcelain"],
      stdout: "piped",
      stderr: "null",
    })
    const output = await proc.output()
    return new TextDecoder().decode(output.stdout).trim().length > 0
  } catch {
    return false
  }
}

// OS icon: starship.toml の [os.symbols] と同じマッピング
const LINUX_DISTRO_ICONS: Record<string, string> = {
  ubuntu: "󰕈",
  debian: "󰣚",
  arch: "󰣇",
  artix: "󰣇",
  fedora: "󰣛",
  alpine: "",
  manjaro: "",
  mint: "󰣭",
  centos: "",
  gentoo: "󰣨",
  raspbian: "󰐿",
  opensuse: "",
  "opensuse-leap": "",
  "opensuse-tumbleweed": "",
  suse: "",
  amzn: "",
  rhel: "󱄛",
  android: "",
}

async function osIcon(): Promise<string> {
  const os = Deno.build.os
  if (os === "darwin") return "󰀵"
  if (os === "windows") return "󰍲"
  if (os === "linux") {
    try {
      const release = await Deno.readTextFile("/etc/os-release")
      const id = release.match(/^ID=("?)([^"\n]+)\1/m)?.[2]?.toLowerCase()
      if (id && LINUX_DISTRO_ICONS[id]) return LINUX_DISTRO_ICONS[id]
    } catch { /* fallback */ }
    return "󰌽"
  }
  return ""
}

// ---- Main ------------------------------------------------------------------

const decoder = new TextDecoder()
const input = decoder.decode(
  await Deno.stdin.readable
    .getReader()
    .read()
    .then((r) => r.value),
)
const data = JSON.parse(input)

const sessionId: string = data.session_id || ""
const transcriptPath: string = data.transcript_path || ""
const cwd: string = data.workspace?.current_dir || data.cwd || ""
const modelName: string = data.model?.display_name || ""
const costUsd: number = data.cost?.total_cost_usd ?? 0
const username = Deno.env.get("USER") || Deno.env.get("LOGNAME") || ""
const termCols = parseInt(Deno.env.get("COLUMNS") || "120", 10) || 120

const tokenTask = (async (): Promise<number> => {
  if (transcriptPath) {
    try {
      const stat = await Deno.stat(transcriptPath)
      if (stat.isFile) return await calculateTokensFromTranscript(transcriptPath)
    } catch { /* not found */ }
  }
  if (sessionId) {
    const projectsDir = `${Deno.env.get("HOME")}/.claude/projects`
    try {
      for await (const entry of Deno.readDir(projectsDir)) {
        if (entry.isDirectory) {
          const f = `${projectsDir}/${entry.name}/${sessionId}.jsonl`
          try {
            const stat = await Deno.stat(f)
            if (stat.isFile) return await calculateTokensFromTranscript(f)
          } catch { /* try next */ }
        }
      }
    } catch { /* no projects dir */ }
  }
  return 0
})()

const [totalTokens, gitBranch, gitDirty, osSym] = await Promise.all([
  tokenTask,
  cwd ? getGitBranch(cwd) : Promise.resolve(""),
  cwd ? getGitDirty(cwd) : Promise.resolve(false),
  osIcon(),
])

const truncatedPath = cwd ? truncatePath(cwd) : ""
const time = new Date().toLocaleTimeString("ja-JP", {
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
})

// ---- Build output ----------------------------------------------------------
const parts: string[] = []

if (username) {
  const icon = osSym ? `${osSym} ` : ""
  parts.push(`${C.orange}${icon}${username}${C.reset}`)
}
if (truncatedPath) parts.push(`${C.yellow}${truncatedPath}${C.reset}`)

if (gitBranch) {
  const dirty = gitDirty ? `${C.orange} *${C.reset}` : ""
  parts.push(`${C.aqua} ${gitBranch}${C.reset}${dirty}`)
}

if (modelName) parts.push(`${C.blue}${modelName}${C.reset}`)

// Context gauge + numeric
{
  const gauge = renderGauge(totalTokens, termCols)
  const labelColor = tokenLabelColor(totalTokens)
  const numeric = `${labelColor}${formatTokens(totalTokens)}${C.reset}`
  let block = `${gauge} ${numeric}`
  if (totalTokens > BASE_CELLS * CELL_TOKENS) {
    const over = totalTokens - BASE_CELLS * CELL_TOKENS
    block += ` ${C.grey}(+${formatTokens(over)})${C.reset}`
  }
  parts.push(block)
}

if (costUsd > 0) {
  parts.push(`${C.blue}$${costUsd.toFixed(2)}${C.reset}`)
}

if (sessionId) {
  parts.push(`${C.grey}⎇ ${sessionId.slice(0, 8)}${C.reset}`)
}

parts.push(`${C.dim}  ${time}${C.reset}`)

console.log(parts.join("  "))
