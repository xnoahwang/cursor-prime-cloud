#Requires -Version 5.1
# cursor-prime: optional destructive-shell guard (fail open on error)
$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) {
        Write-Output '{"permission":"allow"}'
        exit 0
    }

    $input = $raw | ConvertFrom-Json
    $command = [string]$input.command

    $patterns = @(
        'git\s+reset\s+--hard',
        'git\s+push\s+.*--force',
        'git\s+push\s+-f\b',
        'git\s+clean\s+-fd',
        'Remove-Item\s+.*-Recurse\s+-Force',
        'rm\s+-rf',
        'del\s+/f\s+/s',
        'rmdir\s+/s\s+/q',
        'format\s+[a-zA-Z]:',
        'diskpart'
    )

    foreach ($p in $patterns) {
        if ($command -match $p) {
            $msg = 'This shell command may be destructive or irreversible. Review before continuing.'
            Write-Output (@{
                permission    = 'ask'
                user_message  = $msg
                agent_message = 'cursor-prime hook flagged a potentially destructive shell command.'
            } | ConvertTo-Json -Compress)
            exit 0
        }
    }

    Write-Output '{"permission":"allow"}'
    exit 0
}
catch {
    Write-Output '{"permission":"allow"}'
    exit 0
}
