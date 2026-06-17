# PostToolUse hook — format-on-write
# Fires on Write|Edit. Extracts the file path and applies a formatter if one is configured.
#
# Current behavior:
#   .ps1  — skip (no PS formatter configured)
#   .md   — skip (no markdown formatter configured)
#   .ts/.js — runs prettier if available (uncomment below)
#   .py   — runs black if available (uncomment below)
#
# To add a formatter: uncomment the relevant block and adjust the command.

$input_json = $input | Out-String
try { $payload = $input_json | ConvertFrom-Json } catch { exit 0 }

$filePath = if ($payload.file_path) { $payload.file_path }
            elseif ($payload.tool_input.file_path) { $payload.tool_input.file_path }
            else { exit 0 }

if (-not $filePath) { exit 0 }

$ext = [System.IO.Path]::GetExtension($filePath).TrimStart('.').ToLower()

switch ($ext) {
    'ps1' {
        # PowerShell: skip
    }
    'md' {
        # Markdown: skip (no formatter configured)
    }
    { $_ -in @('ts', 'tsx', 'js', 'jsx') } {
        # TypeScript/JavaScript: uncomment to enable prettier
        # if (Get-Command prettier -ErrorAction SilentlyContinue) {
        #     prettier --write $filePath 2>$null
        # }
    }
    'py' {
        # Python: uncomment to enable black
        # if (Get-Command black -ErrorAction SilentlyContinue) {
        #     black $filePath 2>$null
        # }
    }
    default {
        # Plug in your formatter here for other file types.
    }
}

exit 0
