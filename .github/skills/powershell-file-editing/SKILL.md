---
name: powershell-file-editing
description: 'Creates, edits, refactors, and reviews PowerShell files (.ps1, .psm1, .psd1) and embedded PowerShell. Use when generating or changing scripts, modules, manifests, inline deployment or pipeline PowerShell, or authoring and running Pester tests. Not for independent deployment reviews.'
---

# PowerShell File Editing

## Before Edit

- Prefer readable native PowerShell cmdlets over bracketed C#/.NET
  namespace calls when a suitable native equivalent exists.
- For ordinary filesystem tasks, prefer the pairs below. Do not treat
  them as identical for every provider, input, encoding, or error.
  Preserve behavior, encoding, errors, and target compatibility.
- Do: `Join-Path -Path $directory -ChildPath $name`
- Do not: `[System.IO.Path]::Combine($directory, $name)`
- Do: `Test-Path -LiteralPath $path -PathType Leaf`
- Do not: `[System.IO.File]::Exists($path)`
- Keep .NET when no suitable native equivalent exists, or a concrete
  behavior or performance need justifies it.
- Read the target repository for the supported PowerShell edition,
  version, and .NET runtime before choosing cmdlets, parameters, or
  .NET APIs.
- Do not add silent compatibility fallbacks.

## Edit

- Follow existing patterns in the file and nearby scripts.
- Use literal paths and explicit quoting.
- Fail explicitly. Do not swallow errors.
- Make the smallest change and preserve public script behavior.

## Direct Script Style

Prefer the smallest readable script that meets the actual requirement.
No speculative future-proofing, frameworks, extra mutable state,
duplicated checks, or a helper that only wraps one obvious call.
Short names must stay meaningful. Reuse a helper when duplication or
complexity justifies it. Keep validation, isolation, and error handling.
Do not weaken correctness for style. Use a typed collection for a
measured performance or interop need, not by default. Splat long
parameter lists (`Command @params`) instead of one wide line or
backtick continuations. `Select-Object -Unique` is case-sensitive.

Examples are ordinary-input equivalents, not production scripts.

### Unique values
Do:
```powershell
[string[]]$ids = @($rows | Select-Object -ExpandProperty SubscriptionId -Unique)
```
Do not:
```powershell
function Add-UniqueSubscriptionIdentifier {
    param([System.Collections.Generic.List[string]]$Accumulator, [string]$Id)
    if (-not $Accumulator.Contains($Id)) { $Accumulator.Add($Id) }
}
$subscriptionIdAccumulator = [System.Collections.Generic.List[string]]::new()
foreach ($csvRowRecord in $rows) {
    Add-UniqueSubscriptionIdentifier -Accumulator $subscriptionIdAccumulator -Id $csvRowRecord.SubscriptionId
}
$ids = $subscriptionIdAccumulator.ToArray()
```

### Local names
Do:
```powershell
$log = Join-Path -Path $work -ChildPath 'run.log'
Add-Content -LiteralPath $log -Value $line
```
Do not:
```powershell
function Write-RunLogLineViaPathBuilder {
    param($OperationalWorkRoot, $LogLeafName, $LogLinePayload)
    $built = Join-Path -Path $OperationalWorkRoot -ChildPath $LogLeafName
    Add-Content -LiteralPath $built -Value $LogLinePayload
}
Write-RunLogLineViaPathBuilder -OperationalWorkRoot $work -LogLeafName 'run.log' -LogLinePayload $line
```

### Project rows
Collect `foreach` output with `@(...)` to preserve array shape.
Do not grow an array with `+=`.

Do:
```powershell
# Skip blank subscription rows before upload.
$pending = @(
    foreach ($row in $rows) {
        if ([string]::IsNullOrWhiteSpace($row.SubscriptionId)) { continue }
        [pscustomobject]@{ Name = $row.Name; Id = $row.SubscriptionId }
    }
)
```
Do not:
```powershell
# Initialize a typed accumulator, then narrate each obvious step.
$projectedRowAccumulator = [System.Collections.Generic.List[object]]::new()
foreach ($csvRowRecord in $rows) {
    # Evaluate whether this subscription identifier is blank.
    if ([string]::IsNullOrWhiteSpace($csvRowRecord.SubscriptionId)) { continue }
    # Construct a projected record and append it to the accumulator.
    $projectedRowAccumulator.Add([pscustomobject]@{ Name = $csvRowRecord.Name; Id = $csvRowRecord.SubscriptionId })
}
# Materialize the accumulator for downstream callers.
$pending = $projectedRowAccumulator.ToArray()
```

### Look up a value
Use a hashtable directly; do not wrap a simple lookup in a one-use result protocol.

Do:
```powershell
$subscriptions = @{ alpha = 'Development'; beta = 'Production' }
if (-not $subscriptions.ContainsKey($cluster)) {
    throw "Unknown cluster '$cluster'."
}
$subscription = $subscriptions[$cluster]
```
Do not:
```powershell
function Invoke-ClusterSubscriptionResolution {
    param($ClusterIdentifier, $SubscriptionLookupRegistry)
    $resolutionEnvelope = [pscustomobject]@{
        ResolutionSucceeded = $SubscriptionLookupRegistry.ContainsKey($ClusterIdentifier)
        ResolvedSubscription = $null
    }
    if ($resolutionEnvelope.ResolutionSucceeded) {
        $resolutionEnvelope.ResolvedSubscription = $SubscriptionLookupRegistry[$ClusterIdentifier]
    }
    return $resolutionEnvelope
}
$subscriptions = @{ alpha = 'Development'; beta = 'Production' }
$result = Invoke-ClusterSubscriptionResolution -ClusterIdentifier $cluster -SubscriptionLookupRegistry $subscriptions
if (-not $result.ResolutionSucceeded) {
    throw "Unknown cluster '$cluster'."
}
$subscription = $result.ResolvedSubscription
```

## Validate

- Run the smallest existing validation or tests that cover the change.
- For collection changes, test zero, one, and multiple results; preserve
  array shape, element types, and JSON output.
- Do not invent a new runner, runtime, or Pester version for a file
  that already has a harness.
