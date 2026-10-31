param(
	[Parameter(Mandatory = $true)]
	[string[]]$TargetDir,

	[string]$SourceDir = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path,

	[switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourceDir)) {
	throw "Source directory '$SourceDir' does not exist."
}

$SourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path

# Normalize path helper (canonical, case-insensitive comparison on Windows)
function Get-NormalizedPath {
	param([string]$Path)
	return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Test-ExistingPathIsReparsePoint {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path)) {
		return $false
	}

	$item = Get-Item -LiteralPath $Path -Force
	return (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-NoReparsePointInPath {
	param(
		[string]$Path,
		[string]$PathRole
	)

	$currentPath = Get-NormalizedPath $Path

	while (-not [string]::IsNullOrWhiteSpace($currentPath)) {
		if (Test-ExistingPathIsReparsePoint -Path $currentPath) {
			throw "Reparse points are not supported for $PathRole. Found reparse point at '$currentPath'."
		}

		$parentPath = [System.IO.Path]::GetDirectoryName($currentPath)
		if ([string]::IsNullOrWhiteSpace($parentPath) -or [string]::Equals($parentPath, $currentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
			break
		}

		$currentPath = $parentPath
	}
}

$SourceRootNorm = Get-NormalizedPath $SourceRoot
Assert-NoReparsePointInPath -Path $SourceRoot -PathRole "source directory '$SourceRoot'"

$SourceGithubPath = Join-Path $SourceRoot ".github"
$HasSourceGithub = Test-Path -LiteralPath $SourceGithubPath
$SourceGithubNorm = $null
if ($HasSourceGithub) {
	Assert-NoReparsePointInPath -Path $SourceGithubPath -PathRole "source item '$SourceGithubPath'"
	$SourceGithubNorm = Get-NormalizedPath $SourceGithubPath
}

$SourceMcpPath = Join-Path $SourceRoot ".mcp.json"
$HasSourceMcp = Test-Path -LiteralPath $SourceMcpPath
if ($HasSourceMcp) {
	Assert-NoReparsePointInPath -Path $SourceMcpPath -PathRole "source item '$SourceMcpPath'"
	if (-not (Test-Path -LiteralPath $SourceMcpPath -PathType Leaf)) {
		throw "Source item '$SourceMcpPath' must be a file."
	}
}

$SourceClaudePath = Join-Path $SourceRoot ".claude"
$HasSourceClaude = Test-Path -LiteralPath $SourceClaudePath
$SourceClaudeNorm = $null
if ($HasSourceClaude) {
	Assert-NoReparsePointInPath -Path $SourceClaudePath -PathRole "source item '$SourceClaudePath'"
	$SourceClaudeNorm = Get-NormalizedPath $SourceClaudePath
}

# Preflight validation across all targets before any destructive modification
foreach ($Target in $TargetDir) {
	if (-not (Test-Path -LiteralPath $Target)) {
		throw "Target directory '$Target' does not exist."
	}

	$TargetRoot = (Resolve-Path -LiteralPath $Target).Path
	$TargetRootNorm = Get-NormalizedPath $TargetRoot
	Assert-NoReparsePointInPath -Path $TargetRoot -PathRole "target directory '$TargetRoot'"

	if ([string]::Equals($SourceRootNorm, $TargetRootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Target directory '$TargetRoot' is identical to source directory '$SourceRoot'."
	}

	$targetRootPrefix = $TargetRootNorm + [System.IO.Path]::DirectorySeparatorChar

	# Reject target being an ancestor of source (which would make removing target or target config item destroy source)
	if ($SourceRootNorm.StartsWith($targetRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Target directory '$TargetRoot' is an ancestor of source directory '$SourceRoot'."
	}

	$DestAgentsPath = Join-Path $TargetRoot "AGENTS.md"
	Assert-NoReparsePointInPath -Path $DestAgentsPath -PathRole "destination path '$DestAgentsPath'"
	if ((Test-Path -LiteralPath $DestAgentsPath) -and
		(-not (Test-Path -LiteralPath $DestAgentsPath -PathType Leaf))) {
		throw "Destination item '$DestAgentsPath' must be a file."
	}

	if ($HasSourceGithub) {
		$DestGithubPath = Join-Path $TargetRoot ".github"
		Assert-NoReparsePointInPath -Path $DestGithubPath -PathRole "destination path '$DestGithubPath'"

		$DestGithubNorm = Get-NormalizedPath $DestGithubPath

		if ([string]::Equals($SourceGithubNorm, $DestGithubNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
			throw "Target item path '$DestGithubPath' is identical to source item path '$SourceGithubPath'."
		}

		$sourceGithubPrefix = $SourceGithubNorm + [System.IO.Path]::DirectorySeparatorChar
		$destGithubPrefix = $DestGithubNorm + [System.IO.Path]::DirectorySeparatorChar

		if ($DestGithubNorm.StartsWith($sourceGithubPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
			$SourceGithubNorm.StartsWith($destGithubPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
			throw "Unsafe path overlap detected between source item '$SourceGithubPath' and destination item '$DestGithubPath'."
		}

		if ((-not $Force) -and (Test-Path -LiteralPath $DestGithubPath)) {
			throw "'$DestGithubPath' already exists. Re-run with -Force to overwrite."
		}
	}

	if ($HasSourceMcp) {
		$DestMcpPath = Join-Path $TargetRoot ".mcp.json"
		Assert-NoReparsePointInPath -Path $DestMcpPath -PathRole "destination path '$DestMcpPath'"

		if (Test-Path -LiteralPath $DestMcpPath) {
			if (-not (Test-Path -LiteralPath $DestMcpPath -PathType Leaf)) {
				throw "Destination item '$DestMcpPath' must be a file."
			}
			if (-not $Force) {
				throw "'$DestMcpPath' already exists. Re-run with -Force to overwrite."
			}
		}
	}

	$DestClaudePath = Join-Path $TargetRoot ".claude"
	if (Test-Path -LiteralPath $DestClaudePath) {
		Assert-NoReparsePointInPath -Path $DestClaudePath -PathRole "destination path '$DestClaudePath'"

		$DestClaudeNorm = Get-NormalizedPath $DestClaudePath

		if ($HasSourceClaude) {
			if ([string]::Equals($SourceClaudeNorm, $DestClaudeNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
				throw "Target item path '$DestClaudePath' is identical to source item path '$SourceClaudePath'."
			}

			$sourceClaudePrefix = $SourceClaudeNorm + [System.IO.Path]::DirectorySeparatorChar
			$destClaudePrefix = $DestClaudeNorm + [System.IO.Path]::DirectorySeparatorChar

			if ($DestClaudeNorm.StartsWith($sourceClaudePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
				$SourceClaudeNorm.StartsWith($destClaudePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
				throw "Unsafe path overlap detected between source item '$SourceClaudePath' and destination item '$DestClaudePath'."
			}
		}

		if (-not $Force) {
			throw "'$DestClaudePath' already exists. Re-run with -Force to overwrite."
		}

		$traversalQueue = [System.Collections.Generic.Queue[string]]::new()
		$traversalQueue.Enqueue($DestClaudePath)

		while ($traversalQueue.Count -gt 0) {
			$currentFolder = $traversalQueue.Dequeue()
			$dirInfo = [System.IO.DirectoryInfo]::new($currentFolder)

			foreach ($entry in $dirInfo.GetFileSystemInfos()) {
				if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
					throw "Reparse points are not supported inside destination '$DestClaudePath'. Found reparse point at '$($entry.FullName)'."
				}

				if (($entry.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
					$traversalQueue.Enqueue($entry.FullName)
				}
			}
		}

		$skillFiles = Get-ChildItem -LiteralPath $DestClaudePath -File -Recurse -Force |
		Where-Object { [string]::Equals($_.Name, "SKILL.md", [System.StringComparison]::OrdinalIgnoreCase) }

		foreach ($skillFile in $skillFiles) {
			$skillItem = Get-Item -LiteralPath $skillFile.FullName -Force
			if ([string]::Equals($skillItem.LinkType, "HardLink", [System.StringComparison]::OrdinalIgnoreCase)) {
				throw "Hard link SKILL.md is not supported inside destination '$DestClaudePath'. Found hard link at '$($skillItem.FullName)'."
			}
		}
	}
}

Write-Host "Copying agent configuration..."
Write-Host "Source : $SourceRoot"

foreach ($Target in $TargetDir) {

	$TargetRoot = (Resolve-Path -LiteralPath $Target).Path

	Write-Host ""
	Write-Host "Target : $TargetRoot"

	# .github: full replacement from source if available
	$SourceGithubPath = Join-Path $SourceRoot ".github"
	if (-not (Test-Path -LiteralPath $SourceGithubPath)) {
		Write-Host "  skipped (not found): .github"
	}
	else {
		$DestGithubPath = Join-Path $TargetRoot ".github"
		if (Test-Path -LiteralPath $DestGithubPath) {
			if (-not $Force) {
				throw "'$DestGithubPath' already exists. Re-run with -Force to overwrite."
			}
			Remove-Item -LiteralPath $DestGithubPath -Recurse -Force
		}

		if (Test-Path -LiteralPath $SourceGithubPath -PathType Container) {
			Copy-Item -LiteralPath $SourceGithubPath -Destination $TargetRoot -Recurse -Force
		}
		else {
			Copy-Item -LiteralPath $SourceGithubPath -Destination $DestGithubPath -Force
		}

		Write-Host "  copied: .github"
	}

	# .mcp.json: copy source file to each target root if available
	if (-not (Test-Path -LiteralPath $SourceMcpPath)) {
		Write-Host "  skipped (not found): .mcp.json"
	}
	else {
		$DestMcpPath = Join-Path $TargetRoot ".mcp.json"
		if (Test-Path -LiteralPath $DestMcpPath) {
			if (-not $Force) {
				throw "'$DestMcpPath' already exists. Re-run with -Force to overwrite."
			}
			Remove-Item -LiteralPath $DestMcpPath -Force
		}

		Copy-Item -LiteralPath $SourceMcpPath -Destination $DestMcpPath -Force
		Write-Host "  copied: .mcp.json"
	}

	# .claude: sanitize in place if destination exists, preserve directories and empty SKILL.md, delete all other files
	$DestClaudePath = Join-Path $TargetRoot ".claude"
	if (-not (Test-Path -LiteralPath $DestClaudePath)) {
		Write-Host "  skipped (not found): .claude"
	}
	else {
		if (-not $Force) {
			throw "'$DestClaudePath' already exists. Re-run with -Force to overwrite."
		}

		$claudeFiles = Get-ChildItem -LiteralPath $DestClaudePath -File -Recurse -Force
		$removedCount = 0
		$emptiedCount = 0

		foreach ($file in $claudeFiles) {
			if ([string]::Equals($file.Name, "SKILL.md", [System.StringComparison]::OrdinalIgnoreCase)) {
				$origAttr = $file.Attributes
				$needsAttrReset = (($origAttr -band ([System.IO.FileAttributes]::ReadOnly -bor [System.IO.FileAttributes]::Hidden)) -ne 0)
				if ($needsAttrReset) {
					$file.Attributes = [System.IO.FileAttributes]::Normal
				}
				[System.IO.File]::WriteAllBytes($file.FullName, [byte[]]@())
				if ($needsAttrReset) {
					$file.Attributes = $origAttr -band (-bnot [System.IO.FileAttributes]::ReadOnly)
				}
				$emptiedCount++
			}
			else {
				Remove-Item -LiteralPath $file.FullName -Force
				$removedCount++
			}
		}

		Write-Host "  sanitized: .claude ($removedCount removed, $emptiedCount emptied)"
	}

	# Only the destination root file is removed; never copy it from source.
	$DestAgentsPath = Join-Path $TargetRoot "AGENTS.md"
	if (Test-Path -LiteralPath $DestAgentsPath) {
		Remove-Item -LiteralPath $DestAgentsPath -Force
		Write-Host "  removed: AGENTS.md"
	}
	else {
		Write-Host "  already absent: AGENTS.md"
	}
}

Write-Host ""
Write-Host "Done."
