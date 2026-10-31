param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoUrl,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetDir
)

$ErrorActionPreference = "Stop"

$ExcludePaths = @(
    ".claude",
    ".clinerules",
    ".roo",
    ".cursor",
    ".continue",
    ".aider",

    ".github/agents",
    ".github/skills",
    ".github/prompts",
    ".github/chatmodes",
    ".github/instructions",
    ".github/copilot-instructions.md",

    "agents",
    "skills",
    "prompts",
    "AGENTS.md"
)

Write-Host "Cloning repository..."
Write-Host "Repo   : $RepoUrl"
Write-Host "Target : $TargetDir"

if (Test-Path $TargetDir) {
    throw "Target directory '$TargetDir' already exists."
}

git clone --no-checkout $RepoUrl $TargetDir

if ($LASTEXITCODE -ne 0) {
    throw "git clone failed."
}

Push-Location $TargetDir

try {

    git sparse-checkout init --no-cone

    $SparseFile = ".git\info\sparse-checkout"

    $Rules = @()

    # Include everything
    $Rules += "/*"

    # Exclude selected folders/files
    foreach ($Path in $ExcludePaths) {

        $Normalized = $Path.Replace("\", "/").Trim("/")

        $Rules += "!/$Normalized"
        $Rules += "!/$Normalized/"
        $Rules += "!/$Normalized/**"
    }

    $Rules | Set-Content $SparseFile

    git checkout

    Write-Host ""
    Write-Host "Done."
    Write-Host "Repository created at:"
    Write-Host "  $((Resolve-Path .).Path)"
    Write-Host ""
    Write-Host "Excluded paths:"
    $ExcludePaths | ForEach-Object { Write-Host "  $_" }
}
finally {
    Pop-Location
}
