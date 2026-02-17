#!/usr/bin/env -S deno run --allow-run --allow-env --allow-read

interface HookData {
  session_id: string
  transcript_path: string
  hook_event_name: "Stop" | "Notification"
  notification_type?: "permission_prompt" | "idle_prompt" | "auth_success" | "elicitation_dialog"
  stop_hook_active?: boolean
}

const NOTIFICATION_TITLES: Record<string, string> = {
  Stop: "Claude Code",
  permission_prompt: "Permission Required",
  idle_prompt: "Idle",
  auth_success: "Auth Success",
  elicitation_dialog: "Input Required",
}

const runCommand = async (
  cmd: string,
  args: string[],
  cwd?: string,
): Promise<{ success: boolean; stdout: string }> => {
  try {
    const command = new Deno.Command(cmd, {
      args,
      cwd,
      stdout: "piped",
      stderr: "piped",
    })
    const result = await command.output()
    return {
      success: result.success,
      stdout: new TextDecoder().decode(result.stdout).trim(),
    }
  } catch {
    return { success: false, stdout: "" }
  }
}

const getGitInfo = async (cwd: string): Promise<{ repoName: string; branchName: string }> => {
  const gitCheck = await runCommand("git", ["rev-parse", "--is-inside-work-tree"], cwd)
  const isGitRepo = gitCheck.success && gitCheck.stdout === "true"

  let repoName = ""
  let branchName = ""

  if (isGitRepo) {
    const remote = await runCommand("git", ["remote", "get-url", "origin"], cwd)

    if (remote.stdout && remote.success) {
      const match = remote.stdout.match(/[/:]([^/]+?)(?:\.git)?$/)
      repoName = match ? match[1] : ""
    }

    if (!repoName) {
      repoName = cwd.split("/").pop() || ""
    }

    const branch = await runCommand("git", ["branch", "--show-current"], cwd)
    branchName = branch.stdout
  } else {
    repoName = cwd.split("/").pop() || ""
  }

  return { repoName, branchName }
}

const main = async () => {
  const input = await new Response(Deno.stdin.readable).text()
  const data: HookData = JSON.parse(input)

  const cwd = Deno.cwd()
  const { repoName, branchName } = await getGitInfo(cwd)

  const title = data.notification_type
    ? (NOTIFICATION_TITLES[data.notification_type] ?? data.notification_type)
    : (NOTIFICATION_TITLES[data.hook_event_name] ?? data.hook_event_name)

  const subtitle = branchName ? `${repoName} (${branchName})` : repoName
  const message = data.hook_event_name === "Stop" ? "Task completed" : "Action required"

  // Use terminal-notifier for macOS notifications
  await runCommand("terminal-notifier", [
    "-title", title,
    "-subtitle", subtitle,
    "-message", message,
    "-sound", "default",
    "-group", `claude-code-${repoName}`,
  ])

  console.log(JSON.stringify({ success: true }))
}

try {
  await main()
} catch (error) {
  console.log(
    JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : String(error),
    }),
  )
}
