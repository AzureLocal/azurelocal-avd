# PreToolUse hook — blocks writes containing secret patterns
# Event: PreToolUse Write|Edit
# Input: JSON from stdin { tool_name, tool_input: { file_path, content|new_string } }

$input_json = $input | Out-String
try { $payload = $input_json | ConvertFrom-Json } catch { exit 0 }

$content = if ($payload.tool_input.content) { $payload.tool_input.content }
           elseif ($payload.tool_input.new_string) { $payload.tool_input.new_string }
           else { exit 0 }

$patterns = @(
    'api[_-]?key\s*[:=]\s*[''"]?[A-Za-z0-9+/]{20,}',
    'password\s*[:=]\s*[''"]?[^\s''";]{8,}',
    'secret\s*[:=]\s*[''"]?[A-Za-z0-9+/]{16,}',
    'token\s*[:=]\s*[''"]?[A-Za-z0-9._-]{20,}',
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'AKIA[0-9A-Z]{16}',                     # AWS access key
    'ghp_[A-Za-z0-9]{36}',                  # GitHub personal token
    'ghs_[A-Za-z0-9]{36}',                  # GitHub server token
    'sk-[A-Za-z0-9]{48}',                   # OpenAI key
    'DefaultEndpointsProtocol=https.*AccountKey=',  # Azure Storage connection string
    'Server=.*Password='                     # DB connection string with password
)

foreach ($pattern in $patterns) {
    if ($content -match $pattern) {
        Write-Error "BLOCKED: Possible secret detected matching pattern: $pattern"
        exit 1
    }
}

exit 0
