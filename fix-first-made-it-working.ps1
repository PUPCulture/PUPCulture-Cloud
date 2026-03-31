# fix-first-made-it-working.ps1
# Run from repo root:
#   powershell -ExecutionPolicy Bypass -File .\fix-first-made-it-working.ps1

$ErrorActionPreference = "Stop"

function Backup-File([string]$Path) {
  if (Test-Path $Path) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $bak = "$Path.bak_$stamp"
    Copy-Item $Path $bak -Force
    Write-Host "🧾 Backup: $Path -> $bak"
  } else {
    throw "Missing file: $Path"
  }
}

function Patch-ApiIndex() {
  $apiFile = ".\api\src\index.js"
  Backup-File $apiFile

  $content = Get-Content $apiFile -Raw

  # Remove any existing /bot/events route (simple line-based removal)
  $lines = $content -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]

  $inOldRoute = $false

  foreach ($line in $lines) {
    if (-not $inOldRoute) {
      if ($line -match "app\.post\((['" + '"' + "])\/bot\/events\1") {
        $inOldRoute = $true
        continue
      }
      $out.Add($line)
    } else {
      # stop skipping when handler ends
      if ($line -match "^\s*\}\);\s*$") {
        $inOldRoute = $false
      }
    }
  }

  $content = ($out -join "`n")

  $securedRoute = @"
app.post("/bot/events", (req, res) => {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;

  if (!process.env.BOT_API_KEY) {
    return res.status(500).json({ error: "Server missing BOT_API_KEY env" });
  }

  if (!token || token !== process.env.BOT_API_KEY) {
    return res.status(403).json({ error: "Invalid bot api key" });
  }

  return res.json({ ok: true, received: req.body ?? null });
});
"@

  $lines2 = $content -split "`r?`n"
  $out2 = New-Object System.Collections.Generic.List[string]
  $inserted = $false

  foreach ($line in $lines2) {
    if (-not $inserted -and $line -match "app\.listen\s*\(") {
      $out2.Add("")
      $out2.Add("// ---- Bot events endpoint (Cloudflare Access + BOT_API_KEY) ----")
      $out2.Add($securedRoute.TrimEnd())
      $out2.Add("// --------------------------------------------------------------")
      $out2.Add("")
      $inserted = $true
    }
    $out2.Add($line)
  }

  if (-not $inserted) {
    $out2.Add("")
    $out2.Add("// ---- Bot events endpoint (Cloudflare Access + BOT_API_KEY) ----")
    $out2.Add($securedRoute.TrimEnd())
    $out2.Add("// --------------------------------------------------------------")
    $out2.Add("")
  }

  Set-Content $apiFile -Value ($out2 -join "`n") -Encoding UTF8
  Write-Host "✅ Patched api/src/index.js: added secured POST /bot/events"
}

function Patch-DockerCompose() {
  $composeFile = ".\docker-compose.yml"
  Backup-File $composeFile

  $lines = Get-Content $composeFile

  $out = New-Object System.Collections.Generic.List[string]
  $inBot = $false
  $botIndent = 0
  $inEnv = $false
  $envIndent = 0

  for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Enter/exit bot service
    if ($line -match '^(\s*)([A-Za-z0-9_-]+):\s*$') {
      $name = $Matches[2]
      $indent = $Matches[1].Length

      if ($name -eq "bot") {
        $inBot = $true
        $botIndent = $indent
        $inEnv = $false
      } elseif ($inBot -and $indent -le $botIndent) {
        $inBot = $false
        $inEnv = $false
      }
    }

    if ($inBot) {
      # force restart "no"
      if ($line -match '^\s*restart:\s*') {
        $line = (" " * ($botIndent + 2)) + 'restart: "no"'
      }

      # environment block tracking
      if ($line -match '^(\s*)environment:\s*$') {
        $inEnv = $true
        $envIndent = $Matches[1].Length
      } elseif ($inEnv) {
        $curIndent = ($line -match '^(\s*)') | Out-Null
        $curIndent = $Matches[1].Length
        if ($curIndent -le $envIndent) { $inEnv = $false }
      }

      # force API_BASE_URL for Cloudflare
      if ($inEnv -and $line -match '^\s*API_BASE_URL:\s*') {
        $line = (" " * ($envIndent + 2)) + "API_BASE_URL: https://api.pupculture.site"
      }
    }

    $out.Add($line)
  }

  Set-Content $composeFile -Value $out -Encoding UTF8
  Write-Host "✅ Patched docker-compose.yml: bot restart=no and API_BASE_URL=https://api.pupculture.site"
}

function Restart-Stack() {
  Write-Host "🔁 Restarting stack..."
  docker compose down | Out-Null
  docker compose up -d --build | Out-Null
  docker compose ps
}

Write-Host "== Fixing: first made it but working =="
Patch-ApiIndex
Patch-DockerCompose
Restart-Stack
Write-Host "✅ Done."
