# PreToolUse hook — blocks writes to protected paths
# Event: PreToolUse Write|Edit
# Input: JSON from stdin { tool_name, tool_input: { file_path } }

$input_json = $input | Out-String
try { $payload = $input_json | ConvertFrom-Json } catch { exit 0 }

$filePath = $payload.tool_input.file_path
if (-not $filePath) { exit 0 }

$normalizedPath = $filePath.Replace('\', '/').ToLower()

# Add or remove paths as needed for your repo
$blocked = @(
    '/.git/',
    '/node_modules/',
    '/dist/',
    '/.env',
    '/dist-ssr/',
    '/.next/',
    '/build/'
)

foreach ($b in $blocked) {
    if ($normalizedPath -like "*$b*") {
        Write-Error "BLOCKED: Write to protected path: $filePath (matched: $b)"
        exit 1
    }
}

exit 0
