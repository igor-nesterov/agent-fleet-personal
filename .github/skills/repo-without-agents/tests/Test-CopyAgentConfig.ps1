#Requires -Version 7.0
<#
.SYNOPSIS
    Focused regression test suite for agent-configuration clone, copy, and local ignore.
.DESCRIPTION
    Validates replacement semantics for .github and .claude folders and root .mcp.json,
    source-safety guards (self-copy, dangerous overlap), permission/Force rules,
    missing source preservation, first-time copies, idempotency, valid nested roots,
    local ignore rules for untracked files and tracked collisions, and root AGENTS.md
    removal without new status changes. Uses only local Git operations, without commits.
    Operates strictly within isolated temporary fixtures and cleans up after itself.
#>

$copyScript = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts' 'copy-agent-config.ps1')).Path
$ignoreScript = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts' 'ignore-agent-config.ps1')).Path
$cloneScript = (Resolve-Path (Join-Path $PSScriptRoot '..\scripts' 'repo-without-agents.ps1')).Path
$fleetRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path

$script:TestCount = 0
$script:FailCount = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:TestCount++
    if (-not $Condition) {
        $script:FailCount++
        $script:Failures.Add($Message)
        Write-Host "FAIL: $Message" -ForegroundColor Red
    }
    else {
        Write-Host "PASS: $Message" -ForegroundColor Green
    }
}

$tempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("test-copy-config-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempBase -Force | Out-Null
$junctionPaths = [System.Collections.Generic.List[string]]::new()

try {
    # -------------------------------------------------------------------------
    # Test 1: Forced copy replaces .github completely and sanitizes target .claude in place
    # Target .claude preserves directories and empties SKILL.md to 0 bytes; other files removed
    # -------------------------------------------------------------------------
    $src1 = Join-Path $tempBase "src1"
    $tgt1 = Join-Path $tempBase "tgt1"
    New-Item -ItemType Directory -Path (Join-Path $src1 ".github\skills\skillA") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src1 ".github\skills\skillA\SKILL.md") -Value "SkillA source"
    New-Item -ItemType Directory -Path (Join-Path $src1 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src1 ".claude\.gitkeep") -Value "source keep"

    New-Item -ItemType Directory -Path (Join-Path $tgt1 ".github\workflows") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt1 ".github\workflows\stale-upstream.yml") -Value "stale-ci"
    New-Item -ItemType Directory -Path (Join-Path $tgt1 ".claude\commands") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\commands\stale-tool.md") -Value "stale-tool"
    New-Item -ItemType Directory -Path (Join-Path $tgt1 ".claude\skills\skillB") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\skills\skillB\SKILL.md") -Value "original skill content"
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\skills\skillB\notes.txt") -Value "stale notes"
    New-Item -ItemType Directory -Path (Join-Path $tgt1 ".claude\empty-dir") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\root.txt") -Value "stale root file"
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\.dotfile") -Value "stale dotfile"
    Set-Content -LiteralPath (Join-Path $tgt1 ".claude\.gitkeep") -Value "target keep"

    & $copyScript -SourceDir $src1 -TargetDir @($tgt1) -Force

    $staleGithubFound = Test-Path (Join-Path $tgt1 ".github\workflows\stale-upstream.yml")
    $newGithubFound = Test-Path (Join-Path $tgt1 ".github\skills\skillA\SKILL.md")
    $staleCmdFound = Test-Path (Join-Path $tgt1 ".claude\commands\stale-tool.md")
    $staleNotesFound = Test-Path (Join-Path $tgt1 ".claude\skills\skillB\notes.txt")
    $staleRootFound = Test-Path (Join-Path $tgt1 ".claude\root.txt")
    $staleDotFound = Test-Path (Join-Path $tgt1 ".claude\.dotfile")
    $staleKeepFound = Test-Path (Join-Path $tgt1 ".claude\.gitkeep")
    $emptyDirExists = Test-Path (Join-Path $tgt1 ".claude\empty-dir")
    $skillBPath = Join-Path $tgt1 ".claude\skills\skillB\SKILL.md"
    $skillBExists = Test-Path -LiteralPath $skillBPath
    $skillBLen = if ($skillBExists) { (Get-Item -LiteralPath $skillBPath).Length } else { -1 }
    $srcKeepIntact = (Get-Content -LiteralPath (Join-Path $src1 ".claude\.gitkeep")) -eq "source keep"

    Assert (-not $staleGithubFound) "Test 1a: Stale target-only .github file must be removed by forced copy"
    Assert ($newGithubFound) "Test 1b: Intended .github source file copied to target"
    Assert (-not $staleCmdFound -and -not $staleNotesFound -and -not $staleRootFound -and -not $staleDotFound -and -not $staleKeepFound) "Test 1c: Non-SKILL.md files in target .claude recursively removed"
    Assert ($emptyDirExists) "Test 1d: Empty directories in target .claude preserved"
    Assert ($skillBExists -and ($skillBLen -eq 0)) "Test 1e: Target .claude SKILL.md preserved and emptied to exactly 0 bytes"
    Assert ($srcKeepIntact) "Test 1f: Source .claude files remain unmodified"

    # -------------------------------------------------------------------------
    # Test 2: Destination exists without -Force throws and leaves target untouched
    # -------------------------------------------------------------------------
    $src2 = Join-Path $tempBase "src2"
    $tgt2 = Join-Path $tempBase "tgt2"
    New-Item -ItemType Directory -Path (Join-Path $src2 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src2 ".github\file.txt") -Value "new"
    New-Item -ItemType Directory -Path (Join-Path $tgt2 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt2 ".github\file.txt") -Value "old"

    $noForceThrew = $false
    try {
        & $copyScript -SourceDir $src2 -TargetDir @($tgt2)
    }
    catch {
        $noForceThrew = $true
    }
    $targetContentUnchanged = (Get-Content (Join-Path $tgt2 ".github\file.txt")) -eq "old"
    Assert ($noForceThrew -and $targetContentUnchanged) "Test 2: Target existing without -Force throws and leaves target untouched"

    # -------------------------------------------------------------------------
    # Test 3: Missing source .claude still sanitizes existing target .claude; missing source .github skips
    # -------------------------------------------------------------------------
    $src3 = Join-Path $tempBase "src3"
    $tgt3 = Join-Path $tempBase "tgt3"
    New-Item -ItemType Directory -Path (Join-Path $src3 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src3 ".github\source.txt") -Value "source"
    New-Item -ItemType Directory -Path (Join-Path $tgt3 ".claude\skills\sub") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt3 ".claude\skills\sub\SKILL.md") -Value "existing skill"
    Set-Content -LiteralPath (Join-Path $tgt3 ".claude\existing.txt") -Value "delete-me"

    & $copyScript -SourceDir $src3 -TargetDir @($tgt3) -Force
    $targetGithubCopied = Test-Path (Join-Path $tgt3 ".github\source.txt")
    $targetClaudeFileDeleted = -not (Test-Path (Join-Path $tgt3 ".claude\existing.txt"))
    $targetSkillEmpty = (Test-Path (Join-Path $tgt3 ".claude\skills\sub\SKILL.md")) -and ((Get-Item (Join-Path $tgt3 ".claude\skills\sub\SKILL.md")).Length -eq 0)
    Assert ($targetGithubCopied -and $targetClaudeFileDeleted -and $targetSkillEmpty) "Test 3: Missing source .claude still sanitizes existing target .claude"

    # -------------------------------------------------------------------------
    # Test 4: First-time copy to clean target copies .github and leaves absent .claude absent
    # -------------------------------------------------------------------------
    $src4 = Join-Path $tempBase "src4"
    $tgt4 = Join-Path $tempBase "tgt4"
    New-Item -ItemType Directory -Path (Join-Path $src4 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src4 ".github\init.txt") -Value "hello"
    New-Item -ItemType Directory -Path (Join-Path $src4 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src4 ".claude\.gitkeep") -Value ""
    New-Item -ItemType Directory -Path $tgt4 -Force | Out-Null

    & $copyScript -SourceDir $src4 -TargetDir @($tgt4)
    $firstCopySuccess = (Test-Path (Join-Path $tgt4 ".github\init.txt")) -and (-not (Test-Path (Join-Path $tgt4 ".claude")))
    Assert ($firstCopySuccess) "Test 4: Clean target copies .github and leaves absent target .claude absent"

    # -------------------------------------------------------------------------
    # Test 5: Repeat forced copy is idempotent on .github and sanitized .claude
    # -------------------------------------------------------------------------
    New-Item -ItemType Directory -Path (Join-Path $tgt4 ".claude\skills\persisted") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt4 ".claude\skills\persisted\SKILL.md") -Value ""
    & $copyScript -SourceDir $src4 -TargetDir @($tgt4) -Force
    $idempotentSuccess = (Test-Path (Join-Path $tgt4 ".github\init.txt")) -and (Test-Path (Join-Path $tgt4 ".claude\skills\persisted\SKILL.md")) -and ((Get-Item (Join-Path $tgt4 ".claude\skills\persisted\SKILL.md")).Length -eq 0)
    Assert ($idempotentSuccess) "Test 5: Repeat forced copy succeeds and preserves clean state"

    # -------------------------------------------------------------------------
    # Test 6: Same source and target rejected (self-copy)
    # -------------------------------------------------------------------------
    $selfCopyThrew = $false
    try {
        & $copyScript -SourceDir $src4 -TargetDir @($src4) -Force
    }
    catch {
        $selfCopyThrew = $true
    }
    $sourceStillIntact = Test-Path (Join-Path $src4 ".github\init.txt")
    Assert ($selfCopyThrew -and $sourceStillIntact) "Test 6: Self-copy rejected before deletion and source intact"

    # -------------------------------------------------------------------------
    # Test 7: Dangerous overlap rejected before deletion
    # Target directory is parent of source directory (e.g. copying out to parent)
    # or target config path is ancestor of source config path
    # -------------------------------------------------------------------------
    $nestedSource = Join-Path $tgt4 "nested-src"
    New-Item -ItemType Directory -Path (Join-Path $nestedSource ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedSource ".github\deep.txt") -Value "deep"

    $overlapThrew = $false
    try {
        & $copyScript -SourceDir $nestedSource -TargetDir @($tgt4) -Force
    }
    catch {
        $overlapThrew = $true
    }
    $nestedSourceIntact = Test-Path (Join-Path $nestedSource ".github\deep.txt")
    Assert ($overlapThrew -and $nestedSourceIntact) "Test 7: Unsafe overlap rejected before any deletion"

    # -------------------------------------------------------------------------
    # Test 8: Valid nested target root (e.g. sibling subdirectory inside fleet root)
    # Target clone inside source directory (like C:\source\agents-fleet\project-light)
    # Must be allowed as long as actual config items (.github, .claude) do not overlap
    # Target without .claude should have .github copied and .claude absent
    # -------------------------------------------------------------------------
    $nestedClone = Join-Path $src4 "SubClone"
    New-Item -ItemType Directory -Path $nestedClone -Force | Out-Null

    $nestedCloneSuccess = $false
    try {
        & $copyScript -SourceDir $src4 -TargetDir @($nestedClone)
        $nestedCloneSuccess = (Test-Path (Join-Path $nestedClone ".github\init.txt")) -and (-not (Test-Path (Join-Path $nestedClone ".claude")))
    }
    catch {
        $nestedCloneSuccess = $false
    }
    Assert ($nestedCloneSuccess) "Test 8: Valid nested clone subdirectory inside source root allowed"

    # -------------------------------------------------------------------------
    # Test 9: Junction alias target of source rejected before deletion
    # -------------------------------------------------------------------------
    $src9 = Join-Path $tempBase "src9"
    New-Item -ItemType Directory -Path (Join-Path $src9 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src9 ".github\sentinel.txt") -Value "must-survive"
    New-Item -ItemType Directory -Path (Join-Path $src9 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src9 ".claude\.gitkeep") -Value ""

    $aliasTarget9 = Join-Path $tempBase "tgt9-alias"
    New-Item -ItemType Junction -Path $aliasTarget9 -Target $src9 | Out-Null
    $junctionPaths.Add($aliasTarget9)

    $junctionAliasThrew = $false
    try {
        & $copyScript -SourceDir $src9 -TargetDir @($aliasTarget9) -Force
    }
    catch {
        $junctionAliasThrew = $true
    }

    $src9GithubSentinelIntact = Test-Path (Join-Path $src9 ".github\sentinel.txt")
    $src9ClaudeSentinelIntact = Test-Path (Join-Path $src9 ".claude\.gitkeep")
    Assert ($junctionAliasThrew) "Test 9a: Junction alias target of source must be rejected"
    Assert ($src9GithubSentinelIntact -and $src9ClaudeSentinelIntact) "Test 9b: Source sentinels remain intact after rejected junction alias"

    # -------------------------------------------------------------------------
    # Test 10: Linked ancestor in target path is rejected
    # -------------------------------------------------------------------------
    $src10 = Join-Path $tempBase "src10"
    New-Item -ItemType Directory -Path (Join-Path $src10 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src10 ".github\file.txt") -Value "from-source"
    New-Item -ItemType Directory -Path (Join-Path $src10 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src10 ".claude\.gitkeep") -Value ""

    $realTarget10 = Join-Path $tempBase "real-target10"
    New-Item -ItemType Directory -Path $realTarget10 -Force | Out-Null
    $linkedAncestor10 = Join-Path $tempBase "linked-ancestor10"
    New-Item -ItemType Junction -Path $linkedAncestor10 -Target $realTarget10 | Out-Null
    $junctionPaths.Add($linkedAncestor10)
    $target10 = Join-Path $linkedAncestor10 "repo"
    New-Item -ItemType Directory -Path $target10 -Force | Out-Null

    $linkedAncestorThrew = $false
    try {
        & $copyScript -SourceDir $src10 -TargetDir @($target10)
    }
    catch {
        $linkedAncestorThrew = $true
    }

    $target10Unchanged = -not (Test-Path (Join-Path $target10 ".github")) -and -not (Test-Path (Join-Path $target10 ".claude"))
    Assert ($linkedAncestorThrew -and $target10Unchanged) "Test 10: Linked ancestor target path rejected before mutation"

    # -------------------------------------------------------------------------
    # Test 11: Linked destination config root is rejected
    # -------------------------------------------------------------------------
    $src11 = Join-Path $tempBase "src11"
    New-Item -ItemType Directory -Path (Join-Path $src11 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src11 ".github\file.txt") -Value "from-source"
    New-Item -ItemType Directory -Path (Join-Path $src11 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src11 ".claude\.gitkeep") -Value ""

    $target11 = Join-Path $tempBase "tgt11"
    New-Item -ItemType Directory -Path $target11 -Force | Out-Null
    $realGithub11 = Join-Path $tempBase "real-github11"
    New-Item -ItemType Directory -Path $realGithub11 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $realGithub11 "preexisting.txt") -Value "keep"
    $linkedGithub11 = Join-Path $target11 ".github"
    New-Item -ItemType Junction -Path $linkedGithub11 -Target $realGithub11 | Out-Null
    $junctionPaths.Add($linkedGithub11)

    $linkedConfigRootThrew = $false
    try {
        & $copyScript -SourceDir $src11 -TargetDir @($target11) -Force
    }
    catch {
        $linkedConfigRootThrew = $true
    }

    $linkedConfigRootIntact = Test-Path (Join-Path $realGithub11 "preexisting.txt")
    Assert ($linkedConfigRootThrew -and $linkedConfigRootIntact) "Test 11: Linked destination config root rejected before deletion"

    # -------------------------------------------------------------------------
    # Test 12: No-Force conflict on later item throws before first item mutation
    # Source has .github and .claude; target has only .claude
    # -------------------------------------------------------------------------
    $src12 = Join-Path $tempBase "src12"
    New-Item -ItemType Directory -Path (Join-Path $src12 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src12 ".github\source.txt") -Value "new"
    New-Item -ItemType Directory -Path (Join-Path $src12 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src12 ".claude\.gitkeep") -Value ""

    $tgt12 = Join-Path $tempBase "tgt12"
    New-Item -ItemType Directory -Path (Join-Path $tgt12 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt12 ".claude\existing.txt") -Value "existing"

    $noForceLateConflictThrew = $false
    try {
        & $copyScript -SourceDir $src12 -TargetDir @($tgt12)
    }
    catch {
        $noForceLateConflictThrew = $true
    }

    $tgt12GithubWasNotCreated = -not (Test-Path (Join-Path $tgt12 ".github"))
    $tgt12ClaudeIntact = (Get-Content (Join-Path $tgt12 ".claude\existing.txt")) -eq "existing"
    Assert ($noForceLateConflictThrew -and $tgt12GithubWasNotCreated -and $tgt12ClaudeIntact) "Test 12: No-Force detects later-item conflict before any mutation"

    # -------------------------------------------------------------------------
    # Test 13: No-Force preflight is atomic across multiple targets
    # First target empty, second target conflicting; neither target should mutate
    # -------------------------------------------------------------------------
    $src13 = Join-Path $tempBase "src13"
    New-Item -ItemType Directory -Path (Join-Path $src13 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src13 ".github\source.txt") -Value "new"
    New-Item -ItemType Directory -Path (Join-Path $src13 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src13 ".claude\.gitkeep") -Value ""

    $tgt13a = Join-Path $tempBase "tgt13a"
    $tgt13b = Join-Path $tempBase "tgt13b"
    New-Item -ItemType Directory -Path $tgt13a -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tgt13b ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt13b ".claude\existing.txt") -Value "existing"
    Set-Content -LiteralPath (Join-Path $tgt13a "AGENTS.md") -Value "keep root a"
    Set-Content -LiteralPath (Join-Path $tgt13b "AGENTS.md") -Value "keep root b"

    $multiTargetNoForceThrew = $false
    try {
        & $copyScript -SourceDir $src13 -TargetDir @($tgt13a, $tgt13b)
    }
    catch {
        $multiTargetNoForceThrew = $true
    }

    $tgt13aUnchanged = -not (Test-Path (Join-Path $tgt13a ".github")) -and -not (Test-Path (Join-Path $tgt13a ".claude")) -and
    ((Get-Content -LiteralPath (Join-Path $tgt13a "AGENTS.md")) -eq "keep root a")
    $tgt13bUnchanged = -not (Test-Path (Join-Path $tgt13b ".github")) -and ((Get-Content (Join-Path $tgt13b ".claude\existing.txt")) -eq "existing") -and
    ((Get-Content -LiteralPath (Join-Path $tgt13b "AGENTS.md")) -eq "keep root b")
    Assert ($multiTargetNoForceThrew -and $tgt13aUnchanged -and $tgt13bUnchanged) "Test 13: Multi-target No-Force conflict fails before mutating any target, including root AGENTS.md"

    # -------------------------------------------------------------------------
    # Test 14: Descendant reparse point inside target .claude rejected before mutation
    # Sentinel files in external target must remain intact
    # -------------------------------------------------------------------------
    $src14 = Join-Path $tempBase "src14"
    New-Item -ItemType Directory -Path (Join-Path $src14 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src14 ".github\source.txt") -Value "new"
    New-Item -ItemType Directory -Path (Join-Path $src14 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src14 ".claude\.gitkeep") -Value ""

    $tgt14 = Join-Path $tempBase "tgt14"
    New-Item -ItemType Directory -Path (Join-Path $tgt14 ".claude\skills") -Force | Out-Null
    $externalSentinelDir = Join-Path $tempBase "external-sentinel14"
    New-Item -ItemType Directory -Path $externalSentinelDir -Force | Out-Null
    $sentinelFile = Join-Path $externalSentinelDir "sentinel.txt"
    Set-Content -LiteralPath $sentinelFile -Value "external content"

    $descendantJunction = Join-Path $tgt14 ".claude\skills\linked"
    New-Item -ItemType Junction -Path $descendantJunction -Target $externalSentinelDir | Out-Null
    $junctionPaths.Add($descendantJunction)

    $descendantReparseThrew = $false
    try {
        & $copyScript -SourceDir $src14 -TargetDir @($tgt14) -Force
    }
    catch {
        $descendantReparseThrew = $true
    }

    $sentinelIntact = (Test-Path -LiteralPath $sentinelFile) -and ((Get-Content -LiteralPath $sentinelFile) -eq "external content")
    Assert ($descendantReparseThrew -and $sentinelIntact) "Test 14: Descendant reparse point inside target .claude rejected before mutation"

    # -------------------------------------------------------------------------
    # Test 15: Hard-linked target SKILL.md rejected in preflight before any mutation
    # Multi-target run must leave all inventories and sentinel bytes unchanged
    # -------------------------------------------------------------------------
    $src15 = Join-Path $tempBase "src15"
    New-Item -ItemType Directory -Path (Join-Path $src15 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src15 ".github\source.txt") -Value "source"
    New-Item -ItemType Directory -Path (Join-Path $src15 ".claude") -Force | Out-Null
    $sourceSentinel15 = Join-Path $src15 ".claude\source-sentinel.bin"
    $sentinelBytes15 = [byte[]](115, 104, 97, 114, 101, 100, 45, 115, 107, 105, 108, 108, 45, 100, 97, 116, 97)
    [System.IO.File]::WriteAllBytes($sourceSentinel15, $sentinelBytes15)
    $sentinelHex15 = [System.BitConverter]::ToString($sentinelBytes15)

    $externalSentinel15 = Join-Path $tempBase "external-sentinel15.bin"
    New-Item -ItemType HardLink -Path $externalSentinel15 -Target $sourceSentinel15 | Out-Null

    $tgt15a = Join-Path $tempBase "tgt15a"
    New-Item -ItemType Directory -Path (Join-Path $tgt15a ".github") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tgt15a ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt15a ".github\preexisting-a.txt") -Value "keep-a"
    Set-Content -LiteralPath (Join-Path $tgt15a ".claude\regular-a.txt") -Value "keep-a"

    $tgt15b = Join-Path $tempBase "tgt15b"
    New-Item -ItemType Directory -Path (Join-Path $tgt15b ".github") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tgt15b ".claude\skills") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt15b ".github\preexisting-b.txt") -Value "keep-b"
    Set-Content -LiteralPath (Join-Path $tgt15b ".claude\regular-b.txt") -Value "keep-b"
    $hardLinkedSkill15 = Join-Path $tgt15b ".claude\skills\SKILL.md"
    New-Item -ItemType HardLink -Path $hardLinkedSkill15 -Target $sourceSentinel15 | Out-Null

    $hardLinkSkillThrew15 = $false
    $hardLinkSkillExplicit15 = $false
    try {
        & $copyScript -SourceDir $src15 -TargetDir @($tgt15a, $tgt15b) -Force
    }
    catch {
        $hardLinkSkillThrew15 = $true
        $hardLinkSkillExplicit15 = $_.Exception.Message -match "hard.?link"
    }

    $sourceSentinelIntact15 = ([System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($sourceSentinel15))) -eq $sentinelHex15
    $externalSentinelIntact15 = ([System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($externalSentinel15))) -eq $sentinelHex15

    $tgt15aFiles = (Get-ChildItem -LiteralPath $tgt15a -File -Recurse -Force | ForEach-Object { $_.FullName.Substring($tgt15a.Length + 1) } | Sort-Object)
    $tgt15aExpectedFiles = @(".claude\regular-a.txt", ".github\preexisting-a.txt")
    $tgt15aInventoryUnchanged = ((@($tgt15aFiles) -join "|") -eq ((@($tgt15aExpectedFiles) | Sort-Object) -join "|"))
    $tgt15aGithubSentinelPath = Join-Path $tgt15a ".github\preexisting-a.txt"
    $tgt15aClaudeSentinelPath = Join-Path $tgt15a ".claude\regular-a.txt"
    $tgt15aContentsUnchanged = (Test-Path -LiteralPath $tgt15aGithubSentinelPath) -and
    (Test-Path -LiteralPath $tgt15aClaudeSentinelPath) -and
    ((Get-Content -LiteralPath $tgt15aGithubSentinelPath) -eq "keep-a") -and
    ((Get-Content -LiteralPath $tgt15aClaudeSentinelPath) -eq "keep-a")

    $tgt15bFiles = (Get-ChildItem -LiteralPath $tgt15b -File -Recurse -Force | ForEach-Object { $_.FullName.Substring($tgt15b.Length + 1) } | Sort-Object)
    $tgt15bExpectedFiles = @(".claude\regular-b.txt", ".claude\skills\SKILL.md", ".github\preexisting-b.txt")
    $tgt15bInventoryUnchanged = ((@($tgt15bFiles) -join "|") -eq ((@($tgt15bExpectedFiles) | Sort-Object) -join "|"))
    $tgt15bGithubSentinelPath = Join-Path $tgt15b ".github\preexisting-b.txt"
    $tgt15bClaudeSentinelPath = Join-Path $tgt15b ".claude\regular-b.txt"
    $tgt15bContentsUnchanged = (Test-Path -LiteralPath $tgt15bGithubSentinelPath) -and
    (Test-Path -LiteralPath $tgt15bClaudeSentinelPath) -and
    ((Get-Content -LiteralPath $tgt15bGithubSentinelPath) -eq "keep-b") -and
    ((Get-Content -LiteralPath $tgt15bClaudeSentinelPath) -eq "keep-b")
    $tgt15bSkillUnchanged = (Test-Path -LiteralPath $hardLinkedSkill15) -and
    (([System.BitConverter]::ToString([System.IO.File]::ReadAllBytes($hardLinkedSkill15))) -eq $sentinelHex15)

    $allTargetsUnchanged15 = $tgt15aInventoryUnchanged -and $tgt15aContentsUnchanged -and $tgt15bInventoryUnchanged -and $tgt15bContentsUnchanged -and $tgt15bSkillUnchanged
    Assert ($hardLinkSkillThrew15 -and $hardLinkSkillExplicit15 -and $sourceSentinelIntact15 -and $externalSentinelIntact15 -and $allTargetsUnchanged15) "Test 15: Hard-linked target SKILL.md rejected in preflight before any target mutation"

    # -------------------------------------------------------------------------
    # Test 16: First-time multi-target copy puts exact .mcp.json bytes at each root
    # -------------------------------------------------------------------------
    $src16 = Join-Path $tempBase "src16"
    New-Item -ItemType Directory -Path (Join-Path $src16 ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $src16 ".github\fixture.txt") -Value "source github"
    $sourceMcp16 = Join-Path $src16 ".mcp.json"
    Set-Content -LiteralPath $sourceMcp16 -Value '{"mcpServers":{"fixture":{"command":"fixture-only"}}}' -Encoding utf8BOM -NoNewline
    $sourceMcpHash16 = (Get-FileHash -LiteralPath $sourceMcp16).Hash
    $targets16 = @((Join-Path $tempBase "tgt16a"), (Join-Path $tempBase "tgt16b"))
    foreach ($target16 in $targets16) {
        New-Item -ItemType Directory -Path $target16 -Force | Out-Null
    }

    $copyLog16 = @(& $copyScript -SourceDir $src16 -TargetDir $targets16 6>&1)
    foreach ($target16 in $targets16) {
        $targetMcp16 = Join-Path $target16 ".mcp.json"
        $exactRootCopy16 = (Test-Path -LiteralPath $targetMcp16 -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $targetMcp16).Hash -eq $sourceMcpHash16)
        Assert ($exactRootCopy16) "Test 16: Exact .mcp.json bytes copied to repository root '$target16'"
    }
    $copiedReports16 = @($copyLog16 | Where-Object { $_ -match 'copied: \.mcp\.json' })
    Assert ($copiedReports16.Count -eq 2) "Test 16: Each target reports copied .mcp.json"

    # -------------------------------------------------------------------------
    # Test 17: Later-target .mcp.json conflict blocks all changes without -Force
    # Forced overwrite and repeated forced copy retain exact source bytes
    # -------------------------------------------------------------------------
    $tgt17a = Join-Path $tempBase "tgt17a"
    $tgt17b = Join-Path $tempBase "tgt17b"
    New-Item -ItemType Directory -Path $tgt17a, $tgt17b -Force | Out-Null
    $targetMcp17 = Join-Path $tgt17b ".mcp.json"
    Set-Content -LiteralPath $targetMcp17 -Value "old mcp"
    $noForceMcpThrew17 = $false
    try {
        & $copyScript -SourceDir $src16 -TargetDir @($tgt17a, $tgt17b)
    }
    catch {
        $noForceMcpThrew17 = $_.Exception.Message -match '\.mcp\.json.*-Force'
    }
    $targetsUnchanged17 = (@(Get-ChildItem -LiteralPath $tgt17a -Force).Count -eq 0) -and
    (@(Get-ChildItem -LiteralPath $tgt17b -Force).Count -eq 1) -and
    ((Get-Content -LiteralPath $targetMcp17) -eq "old mcp")
    Assert ($noForceMcpThrew17 -and $targetsUnchanged17) "Test 17: Later-target .mcp.json conflict requires -Force before any target mutation"

    foreach ($run17 in 1..2) {
        & $copyScript -SourceDir $src16 -TargetDir @($tgt17a, $tgt17b) -Force
        foreach ($target17 in @($tgt17a, $tgt17b)) {
            $exactOverwrite17 = (Get-FileHash -LiteralPath (Join-Path $target17 ".mcp.json")).Hash -eq $sourceMcpHash16
            Assert ($exactOverwrite17) "Test 17: Forced copy $run17 preserves exact .mcp.json bytes in '$target17'"
        }
    }
    Assert ((Get-FileHash -LiteralPath $sourceMcp16).Hash -eq $sourceMcpHash16) "Test 17: Source .mcp.json remains unchanged"

    # -------------------------------------------------------------------------
    # Test 18: Missing source .mcp.json follows .github skip/preserve policy
    # Existing targets remain untouched with or without -Force
    # -------------------------------------------------------------------------
    $src18 = Join-Path $tempBase "src18"
    $tgt18a = Join-Path $tempBase "tgt18a"
    $tgt18b = Join-Path $tempBase "tgt18b"
    New-Item -ItemType Directory -Path $src18, $tgt18b, (Join-Path $tgt18a ".github") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt18a ".github\existing.txt") -Value "keep github"
    Set-Content -LiteralPath (Join-Path $tgt18a ".mcp.json") -Value "keep mcp"
    foreach ($force18 in @($false, $true)) {
        $copyLog18 = @(& $copyScript -SourceDir $src18 -TargetDir @($tgt18a, $tgt18b) -Force:$force18 6>&1)
        $skippedReports18 = @($copyLog18 | Where-Object { $_ -match 'skipped \(not found\): \.mcp\.json' })
        $targetsPreserved18 = ((Get-Content -LiteralPath (Join-Path $tgt18a ".mcp.json")) -eq "keep mcp") -and
        ((Get-Content -LiteralPath (Join-Path $tgt18a ".github\existing.txt")) -eq "keep github") -and
        (-not (Test-Path -LiteralPath (Join-Path $tgt18b ".mcp.json")))
        Assert ($targetsPreserved18 -and $skippedReports18.Count -eq 2) "Test 18: Missing source .mcp.json reported and skipped without modifying targets (Force=$force18)"
    }

    # -------------------------------------------------------------------------
    # Test 19: Forced replacement unlinks a hard-linked destination before copy
    # -------------------------------------------------------------------------
    $tgt19 = Join-Path $tempBase "tgt19"
    New-Item -ItemType Directory -Path $tgt19 -Force | Out-Null
    $externalMcp19 = Join-Path $tempBase "external-mcp19.json"
    Set-Content -LiteralPath $externalMcp19 -Value "external mcp sentinel"
    $externalMcpHash19 = (Get-FileHash -LiteralPath $externalMcp19).Hash
    $targetMcp19 = Join-Path $tgt19 ".mcp.json"
    New-Item -ItemType HardLink -Path $targetMcp19 -Target $externalMcp19 | Out-Null
    & $copyScript -SourceDir $src16 -TargetDir @($tgt19) -Force
    $hardLinkSafe19 = ((Get-FileHash -LiteralPath $externalMcp19).Hash -eq $externalMcpHash19) -and
    ((Get-FileHash -LiteralPath $targetMcp19).Hash -eq $sourceMcpHash16)
    Assert ($hardLinkSafe19) "Test 19: Forced .mcp.json replacement leaves hard-linked external sentinel unchanged"

    # -------------------------------------------------------------------------
    # Test 20: Source and destination .mcp.json reparse points fail in preflight
    # -------------------------------------------------------------------------
    $src20 = Join-Path $tempBase "src20"
    $tgt20a = Join-Path $tempBase "tgt20a"
    $tgt20b = Join-Path $tempBase "tgt20b"
    $externalMcp20 = Join-Path $tempBase "external-mcp20"
    New-Item -ItemType Directory -Path $src20, $tgt20a, $tgt20b, $externalMcp20 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $externalMcp20 "sentinel.txt") -Value "keep linked content"
    $sourceLink20 = Join-Path $src20 ".mcp.json"
    New-Item -ItemType Junction -Path $sourceLink20 -Target $externalMcp20 | Out-Null
    $junctionPaths.Add($sourceLink20)
    $sourceLinkThrew20 = $false
    try {
        & $copyScript -SourceDir $src20 -TargetDir @($tgt20a) -Force
    }
    catch {
        $sourceLinkThrew20 = $_.Exception.Message -match "Reparse points"
    }
    Assert ($sourceLinkThrew20 -and @(Get-ChildItem -LiteralPath $tgt20a -Force).Count -eq 0) "Test 20a: Linked source .mcp.json rejected before target mutation"

    $targetLink20 = Join-Path $tgt20b ".mcp.json"
    New-Item -ItemType Junction -Path $targetLink20 -Target $externalMcp20 | Out-Null
    $junctionPaths.Add($targetLink20)
    $targetLinkThrew20 = $false
    try {
        & $copyScript -SourceDir $src16 -TargetDir @($tgt20a, $tgt20b) -Force
    }
    catch {
        $targetLinkThrew20 = $_.Exception.Message -match "Reparse points"
    }
    $linkedTargetsUnchanged20 = (@(Get-ChildItem -LiteralPath $tgt20a -Force).Count -eq 0) -and
    (-not (Test-Path -LiteralPath (Join-Path $tgt20b ".github"))) -and
    ((Get-Content -LiteralPath (Join-Path $externalMcp20 "sentinel.txt")) -eq "keep linked content")
    Assert ($targetLinkThrew20 -and $linkedTargetsUnchanged20) "Test 20b: Linked destination .mcp.json rejected before any target mutation"

    # -------------------------------------------------------------------------
    # Test 21: .mcp.json directories are rejected rather than copied or removed
    # -------------------------------------------------------------------------
    $src21 = Join-Path $tempBase "src21"
    $tgt21a = Join-Path $tempBase "tgt21a"
    $tgt21b = Join-Path $tempBase "tgt21b"
    New-Item -ItemType Directory -Path (Join-Path $src21 ".mcp.json"), $tgt21a, (Join-Path $tgt21b ".mcp.json") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt21b ".mcp.json\sentinel.txt") -Value "keep directory"
    $sourceTypeThrew21 = $false
    try {
        & $copyScript -SourceDir $src21 -TargetDir @($tgt21a) -Force
    }
    catch {
        $sourceTypeThrew21 = $_.Exception.Message -match "must be a file"
    }
    Assert ($sourceTypeThrew21 -and @(Get-ChildItem -LiteralPath $tgt21a -Force).Count -eq 0) "Test 21a: Source .mcp.json directory rejected before mutation"
    $targetTypeThrew21 = $false
    try {
        & $copyScript -SourceDir $src16 -TargetDir @($tgt21a, $tgt21b) -Force
    }
    catch {
        $targetTypeThrew21 = $_.Exception.Message -match "must be a file"
    }
    $typeTargetsUnchanged21 = (@(Get-ChildItem -LiteralPath $tgt21a -Force).Count -eq 0) -and
    (-not (Test-Path -LiteralPath (Join-Path $tgt21b ".github"))) -and
    ((Get-Content -LiteralPath (Join-Path $tgt21b ".mcp.json\sentinel.txt")) -eq "keep directory")
    Assert ($targetTypeThrew21 -and $typeTargetsUnchanged21) "Test 21b: Destination .mcp.json directory preserved even with -Force"

    # -------------------------------------------------------------------------
    # Test 22: Existing ignore workflow covers .mcp.json and tracked collisions
    # Stage fixture paths without committing; overwrites must not alter status
    # -------------------------------------------------------------------------
    $untracked22 = Join-Path $tempBase "untracked22"
    $tracked22 = Join-Path $tempBase "tracked22"
    $notGit22 = Join-Path $tempBase "not-git22"
    New-Item -ItemType Directory -Path $notGit22 -Force | Out-Null
    foreach ($repo22 in @($untracked22, $tracked22)) {
        New-Item -ItemType Directory -Path $repo22 -Force | Out-Null
        git -C $repo22 init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw "git init failed for fixture '$repo22'."
        }
        New-Item -ItemType Directory -Path (Join-Path $repo22 ".git\info") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo22 ".git\info\exclude") -Value "# fixture excludes"
    }
    New-Item -ItemType Directory -Path (Join-Path $tracked22 ".github"), (Join-Path $tracked22 ".claude") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tracked22 ".github\fixture.txt") -Value "upstream github"
    Set-Content -LiteralPath (Join-Path $tracked22 ".claude\SKILL.md") -Value "upstream skill"
    Set-Content -LiteralPath (Join-Path $tracked22 ".mcp.json") -Value "upstream mcp"
    git -C $tracked22 add --force -- .github/ .claude/ .mcp.json
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed for fixture '$tracked22'."
    }
    $statusBefore22 = @(git -C $tracked22 status --short)

    & $ignoreScript -TargetDir @($untracked22, $tracked22, $notGit22)
    & $copyScript -SourceDir $src16 -TargetDir @($untracked22, $tracked22) -Force
    & $ignoreScript -TargetDir @($untracked22, $tracked22)

    foreach ($repo22 in @($untracked22, $tracked22)) {
        $excludeLines22 = @(Get-Content -LiteralPath (Join-Path $repo22 ".git\info\exclude"))
        foreach ($ignore22 in @(".github/", ".claude/", ".mcp.json", "/AGENTS.md")) {
            $entryCount22 = @($excludeLines22 | Where-Object { $_ -eq $ignore22 }).Count
            Assert ($entryCount22 -eq 1) "Test 22: Ignore entry '$ignore22' appears once in '$repo22' after rerun"
        }
        Assert ((Get-FileHash -LiteralPath (Join-Path $repo22 ".mcp.json")).Hash -eq $sourceMcpHash16) "Test 22: Ignore workflow retains exact copied .mcp.json in '$repo22'"
    }
    $trackedFlags22 = @(git -C $tracked22 ls-files -v -- .github/ .claude/ .mcp.json)
    $allAssumeUnchanged22 = ($trackedFlags22 -contains "h .github/fixture.txt") -and
    ($trackedFlags22 -contains "h .claude/SKILL.md") -and
    ($trackedFlags22 -contains "h .mcp.json")
    Assert ($allAssumeUnchanged22) "Test 22: Tracked .github, .claude, and root .mcp.json marked assume-unchanged"
    Assert (@(git -C $untracked22 status --short).Count -eq 0) "Test 22: Untracked copied configuration stays out of git status"
    $statusAfter22 = @(git -C $tracked22 status --short)
    $trackedDiff22 = @(git -C $tracked22 diff --name-only -- .github/ .claude/ .mcp.json)
    Assert (($statusAfter22 -join "`n") -eq ($statusBefore22 -join "`n") -and $trackedDiff22.Count -eq 0) "Test 22: Tracked overwrites add no working-tree diff or git status changes; staged baseline preserved"
    Assert (-not (Test-Path -LiteralPath (Join-Path $notGit22 ".git"))) "Test 22: Target without .git/info/exclude remains skipped"
    foreach ($repo22 in @($untracked22, $tracked22)) {
        Set-Content -LiteralPath (Join-Path $repo22 "ordinary.txt") -Value "ordinary file"
        Assert (@(git -C $repo22 status --short) -contains "?? ordinary.txt") "Test 22: Unrelated file remains visible in git status for '$repo22'"
    }

    # -------------------------------------------------------------------------
    # Test 23: A source containing only .mcp.json and one tracked collision work
    # -------------------------------------------------------------------------
    $src23 = Join-Path $tempBase "src23"
    New-Item -ItemType Directory -Path $src23 -Force | Out-Null
    Copy-Item -LiteralPath $sourceMcp16 -Destination (Join-Path $src23 ".mcp.json")
    $singleMcp23 = Join-Path $untracked22 ".mcp.json"
    Set-Content -LiteralPath $singleMcp23 -Value "single tracked upstream"
    git -C $untracked22 add --force -- .mcp.json
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed for single-path fixture '$untracked22'."
    }
    $singleStatusBefore23 = @(git -C $untracked22 status --short)
    & $copyScript -SourceDir $src23 -TargetDir @($untracked22) -Force
    & $ignoreScript -TargetDir @($untracked22)
    $singleFlags23 = @(git -C $untracked22 ls-files -v -- .github/ .claude/ .mcp.json)
    Assert ($singleFlags23.Count -eq 1 -and $singleFlags23 -contains "h .mcp.json") "Test 23: Single tracked root .mcp.json marked assume-unchanged"
    $singleStatusAfter23 = @(git -C $untracked22 status --short)
    $singleDiff23 = @(git -C $untracked22 diff --name-only -- .mcp.json)
    Assert (($singleStatusAfter23 -join "`n") -eq ($singleStatusBefore23 -join "`n") -and $singleDiff23.Count -eq 0) "Test 23: Single tracked .mcp.json overwrite adds no git status changes"
    Assert ((Get-FileHash -LiteralPath $singleMcp23).Hash -eq $sourceMcpHash16) "Test 23: MCP-only source copies exact .mcp.json bytes"

    # -------------------------------------------------------------------------
    # Test 24: Copy removes only target root AGENTS.md, without requiring -Force
    # Hard-linked/read-only roots, multiple targets, reruns, and self-copy safety
    # -------------------------------------------------------------------------
    $src24 = Join-Path $tempBase "src24"
    New-Item -ItemType Directory -Path $src24 -Force | Out-Null
    $sourceAgents24 = Join-Path $src24 "AGENTS.md"
    Set-Content -LiteralPath $sourceAgents24 -Value "fleet root must survive"
    $sourceAgentsHash24 = (Get-FileHash -LiteralPath $sourceAgents24).Hash
    $targets24 = @((Join-Path $tempBase "tgt24a [local]"), (Join-Path $tempBase "tgt24b"))
    foreach ($target24 in $targets24) {
        New-Item -ItemType Directory -Path (Join-Path $target24 "nested") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $target24 "nested\AGENTS.md") -Value "keep nested agents"
        Set-Content -LiteralPath (Join-Path $target24 "ordinary.txt") -Value "keep ordinary work"
    }
    New-Item -ItemType HardLink -Path (Join-Path $targets24[0] "AGENTS.md") -Target $sourceAgents24 | Out-Null
    Set-Content -LiteralPath (Join-Path $targets24[1] "AGENTS.md") -Value "remove read-only root"
    Set-ItemProperty -LiteralPath (Join-Path $targets24[1] "AGENTS.md") -Name IsReadOnly -Value $true
    foreach ($run24 in 1..2) {
        & $copyScript -SourceDir $src24 -TargetDir $targets24
        foreach ($target24 in $targets24) {
            $rootOnly24 = (-not (Test-Path -LiteralPath (Join-Path $target24 "AGENTS.md"))) -and
            ((Get-Content -LiteralPath (Join-Path $target24 "nested\AGENTS.md")) -eq "keep nested agents") -and
            ((Get-Content -LiteralPath (Join-Path $target24 "ordinary.txt")) -eq "keep ordinary work")
            Assert ($rootOnly24) "Test 24: Copy $run24 removes only root AGENTS.md without -Force in '$target24'"
        }
    }
    $selfCopyThrew24 = $false
    try {
        & $copyScript -SourceDir $src24 -TargetDir @($src24) -Force
    }
    catch {
        $selfCopyThrew24 = $_.Exception.Message -match "identical to source"
    }
    Assert ($selfCopyThrew24 -and (Get-FileHash -LiteralPath $sourceAgents24).Hash -eq $sourceAgentsHash24) "Test 24: Source root AGENTS.md survives hard-link deletion and rejected self-copy"

    # -------------------------------------------------------------------------
    # Test 25: Real index/status checks for untracked, tracked, missing, absent roots
    # Keep staged baselines (no fixture commits); staged AGENTS.md must stay visible
    # -------------------------------------------------------------------------
    $untracked25 = Join-Path $tempBase "untracked25 [local]"
    $tracked25 = Join-Path $tempBase "tracked25"
    $missing25 = Join-Path $tempBase "missing25"
    $absent25 = Join-Path $tempBase "absent25"
    $repos25 = @($untracked25, $tracked25, $missing25, $absent25)
    $statusBefore25 = @{}
    $stagedBefore25 = @{}
    $indexBefore25 = @{}
    foreach ($repo25 in $repos25) {
        New-Item -ItemType Directory -Path (Join-Path $repo25 "nested") -Force | Out-Null
        git -C $repo25 init --quiet
        if ($LASTEXITCODE -ne 0) { throw "git init failed for '$repo25'." }
        New-Item -ItemType Directory -Path (Join-Path $repo25 ".git\info") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo25 ".git\info\exclude") -Value "# fixture excludes"
        Set-Content -LiteralPath (Join-Path $repo25 "nested\AGENTS.md") -Value "keep nested agents"
        Set-Content -LiteralPath (Join-Path $repo25 "ordinary.txt") -Value "staged ordinary work"
        git -C $repo25 add -- nested/AGENTS.md ordinary.txt
        if ($LASTEXITCODE -ne 0) { throw "git add failed for '$repo25'." }
        Set-Content -LiteralPath (Join-Path $repo25 "ordinary.txt") -Value "unstaged ordinary work"
        if ($repo25 -in @($tracked25, $missing25)) {
            Set-Content -LiteralPath (Join-Path $repo25 "AGENTS.md") -Value "staged root must survive in index"
            git -C $repo25 add -- AGENTS.md
            if ($LASTEXITCODE -ne 0) { throw "git add AGENTS.md failed for '$repo25'." }
        }
        if ($repo25 -eq $untracked25) {
            New-Item -ItemType HardLink -Path (Join-Path $repo25 "AGENTS.md") -Target $sourceAgents24 | Out-Null
        }
        $statusBefore25[$repo25] = (@(git -C $repo25 status --short --untracked-files=all) |
            Where-Object { $_ -cne "?? AGENTS.md" }) -join "`n"
        $stagedBefore25[$repo25] = @(git -C $repo25 diff --cached --binary) -join "`n"
        $indexBefore25[$repo25] = @(git -C $repo25 ls-files --stage) -join "`n"
    }
    Remove-Item -LiteralPath (Join-Path $missing25 "AGENTS.md")
    Assert (@(git -C $missing25 status --short) -contains "AD AGENTS.md") "Test 25: Already-missing tracked root initially has a real working-tree deletion"

    foreach ($run25 in 1..2) {
        $ignoreLog25 = @(& $ignoreScript -TargetDir $repos25 3>&1 6>&1)
        $stagedWarnings25 = @($ignoreLog25 | Where-Object { $_ -match "preexisting staged changes.*remain visible" })
        Assert ($stagedWarnings25.Count -eq 2) "Test 25: Ignore $run25 explicitly reports both preexisting staged root changes"
        foreach ($repo25 in $repos25) {
            $rootDiff25 = @(git -C $repo25 diff --name-only -- AGENTS.md)
            Assert ((-not (Test-Path -LiteralPath (Join-Path $repo25 "AGENTS.md"))) -and $rootDiff25.Count -eq 0) "Test 25: Ignore $run25 really deletes root without an unstaged deletion in '$repo25'"
        }
        if ($run25 -eq 1) {
            foreach ($repo25 in $repos25) {
                Set-Content -LiteralPath (Join-Path $repo25 "AGENTS.md") -Value "recreated root"
            }
            $rootIgnore25 = @(git -C $untracked25 check-ignore --no-index -- AGENTS.md)
            Assert ($LASTEXITCODE -eq 0 -and $rootIgnore25 -contains "AGENTS.md") "Test 25: Recreated untracked root is locally ignored"
            $nestedIgnore25 = @(git -C $untracked25 check-ignore --no-index -- nested/AGENTS.md)
            Assert ($LASTEXITCODE -eq 1 -and $nestedIgnore25.Count -eq 0) "Test 25: Root-only exclusion does not ignore nested AGENTS.md"
            & $copyScript -SourceDir $src24 -TargetDir $repos25
            foreach ($repo25 in $repos25) {
                Assert (-not (Test-Path -LiteralPath (Join-Path $repo25 "AGENTS.md"))) "Test 25: Copy also removes recreated root in '$repo25'"
            }
        }
    }
    foreach ($repo25 in $repos25) {
        $statusAfter25 = @(git -C $repo25 status --short --untracked-files=all) -join "`n"
        $stagedAfter25 = @(git -C $repo25 diff --cached --binary) -join "`n"
        $indexAfter25 = @(git -C $repo25 ls-files --stage) -join "`n"
        Assert ($statusAfter25 -eq $statusBefore25[$repo25] -and
            $stagedAfter25 -eq $stagedBefore25[$repo25] -and
            $indexAfter25 -eq $indexBefore25[$repo25]) "Test 25: Exact status, staged content, and index entries preserved in '$repo25'"
        $flags25 = @(git -C $repo25 ls-files -v -- AGENTS.md nested/AGENTS.md ordinary.txt)
        $rootFlag25 = if ($repo25 -in @($tracked25, $missing25)) { $flags25 -contains "h AGENTS.md" } else { $flags25 -notcontains "h AGENTS.md" }
        $excludeLines25 = @(Get-Content -LiteralPath (Join-Path $repo25 ".git\info\exclude"))
        $rootEntries25 = @($excludeLines25 | Where-Object { $_ -ceq "/AGENTS.md" })
        Assert ($rootFlag25 -and $flags25 -contains "H nested/AGENTS.md" -and
            $flags25 -contains "H ordinary.txt" -and $rootEntries25.Count -eq 1 -and
            (Get-Content -LiteralPath (Join-Path $repo25 "nested\AGENTS.md")) -eq "keep nested agents" -and
            (Get-Content -LiteralPath (Join-Path $repo25 "ordinary.txt")) -eq "unstaged ordinary work") "Test 25: Only root is hidden; nested/ordinary work and one root exclusion survive in '$repo25'"
    }
    Assert ((Get-FileHash -LiteralPath $sourceAgents24).Hash -eq $sourceAgentsHash24) "Test 25: Ignore unlinks a hard-linked root without modifying source fleet bytes"

    # -------------------------------------------------------------------------
    # Test 26: Root directories/reparse points are rejected, never recursively deleted
    # -------------------------------------------------------------------------
    $tgt26a = Join-Path $tempBase "tgt26a"
    $tgt26b = Join-Path $tempBase "tgt26b"
    $tgt26c = Join-Path $tempBase "tgt26c"
    $external26 = Join-Path $tempBase "external26"
    New-Item -ItemType Directory -Path $tgt26a, (Join-Path $tgt26b "AGENTS.md"), $tgt26c, $external26 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tgt26a "AGENTS.md") -Value "keep first target"
    Set-Content -LiteralPath (Join-Path $tgt26b "AGENTS.md\sentinel.txt") -Value "keep directory"
    Set-Content -LiteralPath (Join-Path $external26 "sentinel.txt") -Value "keep external"
    $rootLink26 = Join-Path $tgt26c "AGENTS.md"
    New-Item -ItemType Junction -Path $rootLink26 -Target $external26 | Out-Null
    $junctionPaths.Add($rootLink26)
    foreach ($unsafe26 in @($tgt26b, $tgt26c)) {
        $copyThrew26 = $false
        try {
            & $copyScript -SourceDir $src24 -TargetDir @($tgt26a, $unsafe26) -Force
        }
        catch {
            $copyThrew26 = $_.Exception.Message -match "must be a file|Reparse points"
        }
        Assert ($copyThrew26 -and (Get-Content -LiteralPath (Join-Path $tgt26a "AGENTS.md")) -eq "keep first target") "Test 26: Unsafe root '$unsafe26' blocks copy before any target deletion"
        git -C $unsafe26 init --quiet
        if ($LASTEXITCODE -ne 0) { throw "git init failed for '$unsafe26'." }
        $ignoreThrew26 = $false
        try {
            & $ignoreScript -TargetDir @($unsafe26)
        }
        catch {
            $ignoreThrew26 = $_.Exception.Message -match "must be a file"
        }
        Assert ($ignoreThrew26) "Test 26: Ignore rejects unsafe root '$unsafe26'"
    }
    Assert ((Get-Content -LiteralPath (Join-Path $tgt26b "AGENTS.md\sentinel.txt")) -eq "keep directory" -and
        (Get-Content -LiteralPath (Join-Path $external26 "sentinel.txt")) -eq "keep external") "Test 26: Directory and linked external contents remain intact"

    # -------------------------------------------------------------------------
    # Test 27: Local-only clone and Git's sparse matcher verify root-only exclusion
    # Reuse existing history read-only, so no network or new commits are needed
    # -------------------------------------------------------------------------
    $clone27 = Join-Path $tempBase "clone27"
    & $cloneScript -RepoUrl $fleetRoot -TargetDir $clone27
    $matchingPaths27 = @(@("AGENTS.md", "nested/AGENTS.md", "README.md") |
        git -C $clone27 sparse-checkout check-rules)
    if ($LASTEXITCODE -ne 0) { throw "git sparse-checkout check-rules failed for '$clone27'." }
    Assert ($matchingPaths27.Count -eq 2 -and $matchingPaths27 -contains "nested/AGENTS.md" -and
        $matchingPaths27 -contains "README.md") "Test 27: Real Git sparse rules exclude only root AGENTS.md, not nested AGENTS.md"
    Assert ((-not (Test-Path -LiteralPath (Join-Path $clone27 "AGENTS.md"))) -and
        (-not (Test-Path -LiteralPath (Join-Path $clone27 ".github\agents"))) -and
        (Test-Path -LiteralPath (Join-Path $clone27 "README.md") -PathType Leaf)) "Test 27: Local clone has no root AGENTS.md and preserves existing sparse behavior"
    Assert (@(git -C $clone27 status --short).Count -eq 0) "Test 27: Local clone has clean git status"
    $cloneRerunThrew27 = $false
    try {
        & $cloneScript -RepoUrl $fleetRoot -TargetDir $clone27
    }
    catch {
        $cloneRerunThrew27 = $_.Exception.Message -match "already exists"
    }
    Assert ($cloneRerunThrew27 -and @(git -C $clone27 status --short).Count -eq 0) "Test 27: Clone rerun still rejects existing targets without changing them"
}
finally {
    foreach ($junctionPath in $junctionPaths) {
        if (Test-Path -LiteralPath $junctionPath) {
            $junctionItem = Get-Item -LiteralPath $junctionPath -Force
            $isReparsePoint = ($junctionItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

            if ($isReparsePoint) {
                Remove-Item -LiteralPath $junctionPath -Force -ErrorAction SilentlyContinue
            }
            else {
                Remove-Item -LiteralPath $junctionPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (Test-Path -LiteralPath $tempBase) {
        Remove-Item -LiteralPath $tempBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Assert (-not (Test-Path -LiteralPath $tempBase)) "Temporary fixture root cleaned: $tempBase"

Write-Host ""
Write-Host "Total tests: $script:TestCount, Failures: $script:FailCount"
if ($script:FailCount -gt 0) {
    exit 1
}
exit 0
