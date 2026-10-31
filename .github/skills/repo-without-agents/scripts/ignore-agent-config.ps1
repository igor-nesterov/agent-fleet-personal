param(
	[Parameter(Mandatory = $true)]
	[string[]]$TargetDir
)

$ErrorActionPreference = "Stop"

$IgnoreItems = @(
	".github/",
	".claude/",
	".mcp.json",
	"/AGENTS.md"
)

Write-Host "Updating local git ignore files..."

foreach ($Target in $TargetDir) {

	if (-not (Test-Path -LiteralPath $Target)) {
		throw "Target directory '$Target' does not exist."
	}

	$TargetRoot = (Resolve-Path -LiteralPath $Target).Path

	Write-Host ""
	Write-Host "Target : $TargetRoot"

	$ExcludeFile = Join-Path $TargetRoot ".git\info\exclude"

	if (-not (Test-Path -LiteralPath $ExcludeFile)) {
		Write-Host "  skipped (not a git repository or missing .git/info/exclude)"
		continue
	}

	$AgentsPath = Join-Path $TargetRoot "AGENTS.md"
	if (Test-Path -LiteralPath $AgentsPath) {
		$AgentsItem = Get-Item -LiteralPath $AgentsPath -Force
		if ($AgentsItem.PSIsContainer -or
			($AgentsItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
			throw "Destination item '$AgentsPath' must be a file, not a directory or reparse point."
		}
	}

	$ExistingLines = @(Get-Content -LiteralPath $ExcludeFile)

	foreach ($Ignore in $IgnoreItems) {

		if ($ExistingLines -contains $Ignore) {
			Write-Host "  already ignored: $Ignore"
			continue
		}

		Add-Content -LiteralPath $ExcludeFile -Value $Ignore
		Write-Host "  ignored: $Ignore"
	}

	Push-Location -LiteralPath $TargetRoot

	try {
		# Exclude rules use a leading slash for root-only matching; Git pathspecs do not.
		$TrackedPaths = @(git ls-files -- ($IgnoreItems -replace '^/', '')) | Where-Object { $_ }
		if ($LASTEXITCODE -ne 0) {
			throw "git ls-files failed in '$TargetRoot'."
		}

		$StagedAgents = @(git diff --cached --name-only -- AGENTS.md)
		if ($LASTEXITCODE -ne 0) {
			throw "git diff --cached failed in '$TargetRoot'."
		}
		if ($StagedAgents.Count -gt 0) {
			Write-Warning "Root AGENTS.md has preexisting staged changes in '$TargetRoot'; they are preserved and remain visible in git status. This script does not stage removal."
		}

		if ($TrackedPaths.Count -eq 0) {
			Write-Host "  no tracked agent-configuration paths to hide"
		}
		else {
			git update-index --assume-unchanged -- $TrackedPaths

			if ($LASTEXITCODE -ne 0) {
				throw "git update-index --assume-unchanged failed in '$TargetRoot'."
			}

			foreach ($TrackedPath in $TrackedPaths) {
				Write-Host "  assume-unchanged: $TrackedPath"
			}
		}

		# Mark tracked entries first, including entries whose file is already missing.
		if (Test-Path -LiteralPath $AgentsPath) {
			Remove-Item -LiteralPath $AgentsPath -Force
			Write-Host "  removed: AGENTS.md"
		}
		else {
			Write-Host "  already absent: AGENTS.md"
		}
	}
	finally {
		Pop-Location
	}
}

Write-Host ""
Write-Host "Done."
