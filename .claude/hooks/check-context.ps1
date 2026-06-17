# Context watcher for Claude Code (UserPromptSubmit hook).
#
# When the active session's input context exceeds THRESHOLD tokens, injects a
# system reminder telling Claude to write a memory dump and prompt the user
# to /clear. The user does the /clear themselves; this script never blocks
# the prompt.
#
# INSTALL: copy to ~/.claude/hooks/check-context.ps1
# Register in ~/.claude/settings.json under hooks.UserPromptSubmit (see
# settings.user-level.json.template in this directory).
#
# Failure mode: any error → exit 0 silently. The user's prompt is never
# delayed by a parsing or IO problem here.

$THRESHOLD = 90000

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $hookInput = $stdin | ConvertFrom-Json -ErrorAction Stop
    $transcriptPath = $hookInput.transcript_path
    if ([string]::IsNullOrWhiteSpace($transcriptPath) -or `
        -not (Test-Path -LiteralPath $transcriptPath)) {
        exit 0
    }

    $lines = [System.IO.File]::ReadAllLines($transcriptPath)
    if ($lines.Count -eq 0) { exit 0 }

    # Walk backwards to find the most recent assistant turn that recorded
    # token usage. Total context = input_tokens + cache_creation + cache_read.
    $tokens = 0
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        try {
            $entry = $line | ConvertFrom-Json -ErrorAction Stop
        } catch { continue }

        $usage = $entry.message.usage
        if (-not $usage) { $usage = $entry.usage }
        if (-not $usage) { continue }
        if (-not $usage.input_tokens) { continue }

        $cacheCreate = if ($usage.cache_creation_input_tokens) {
            [int]$usage.cache_creation_input_tokens
        } else { 0 }
        $cacheRead = if ($usage.cache_read_input_tokens) {
            [int]$usage.cache_read_input_tokens
        } else { 0 }
        $tokens = [int]$usage.input_tokens + $cacheCreate + $cacheRead
        break
    }

    # Fallback: char-count / 4 if no usage telemetry found (very early
    # in a session, or if the schema changed).
    if ($tokens -eq 0) {
        $totalChars = 0
        foreach ($line in $lines) { $totalChars += $line.Length }
        $tokens = [int]($totalChars / 4)
    }

    if ($tokens -lt $THRESHOLD) { exit 0 }

    $tokensK = [math]::Round($tokens / 1000)
    $thresholdK = [math]::Round($THRESHOLD / 1000)

    $msg = @"
[CONTEXT-WATCH] Session context: ~${tokensK}k tokens (threshold: ${thresholdK}k).

Before responding to the user's actual message, write a comprehensive memory dump covering everything from this session that should survive a /clear: in-flight work (branches, files, PR/issue numbers, mid-implementation state), decisions made and their reasoning, bugs found and fixes applied, blockers, open questions, verification status, and any user feedback or preferences observed.

Write to this project's auto-memory directory (the path is in the auto-memory section of your system prompt). Use existing categories (project / feedback / user / reference) and your judgement on granularity — broad is better than narrow. Update MEMORY.md.

End your turn with this exact line:
"Memory saved (N files updated). Run /clear when ready — your next session will auto-load."

The user has explicitly chosen to handle /clear themselves. Do NOT attempt to clear the session or run any harness command yourself.

If this reminder fires again on a subsequent turn (because /clear hasn't happened yet), append/update incrementally — don't rewrite from scratch.
"@

    $output = @{
        hookSpecificOutput = @{
            hookEventName     = "UserPromptSubmit"
            additionalContext = $msg
        }
    } | ConvertTo-Json -Depth 4 -Compress

    [Console]::Out.Write($output)
    exit 0
}
catch {
    # Fail open — never block the user.
    exit 0
}
