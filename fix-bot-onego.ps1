$ErrorActionPreference = "Stop"

function Backup-File([string]$Path) {
  if (Test-Path $Path) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $Path "$Path.bak_$stamp" -Force
    Write-Host "Backup created for $Path"
  }
}

function Fix-DockerCompose() {
  $p = ".\docker-compose.yml"
  if (-not (Test-Path $p)) { throw "Missing docker-compose.yml" }
  Backup-File $p

  $lines = Get-Content $p

  $out = New-Object System.Collections.Generic.List[string]
  $inBot = $false
  $inBotEnv = $false
  $botIndent = 0
  $envIndent = 0
  $sawApiBase = $false
  $sawDependsOn = $false
  $sawRestart = $false

  for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Detect service headers like "bot:"
    if ($line -match '^(\s*)([A-Za-z0-9_-]+):\s*$') {
      $name = $Matches[2]
      $indent = $Matches[1].Length

      if ($name -eq "bot") {
        $inBot = $true
        $inBotEnv = $false
        $botIndent = $indent
        $sawApiBase = $false
        $sawDependsOn = $false
        $sawRestart = $false
      } elseif ($inBot -and $indent -le $botIndent) {
        # Leaving bot block: inject missing keys before moving on
        if (-not $sawRestart) {
          $out.Add((" " * ($botIndent + 2)) + "restart: unless-stopped")
        }
        if (-not $sawDependsOn) {
          $out.Add((" " * ($botIndent + 2)) + "depends_on:")
          $out.Add((" " * ($botIndent + 4)) + "- api")
        }
        if ($inBotEnv -and -not $sawApiBase) {
          $out.Add((" " * ($envIndent + 2)) + "API_BASE_URL: http://api:3001")
          $sawApiBase = $true
        }
        $inBot = $false
        $inBotEnv = $false
      }
    }

    if ($inBot) {
      if ($line -match '^\s*restart:\s*') { $sawRestart = $true }
      if ($line -match '^\s*depends_on:\s*$') { $sawDependsOn = $true }

      # Track environment block indentation inside bot
      if ($line -match '^(\s*)environment:\s*$') {
        $inBotEnv = $true
        $envIndent = $Matches[1].Length
      } elseif ($inBotEnv) {
        $curIndent = ($line -match '^(\s*)') | Out-Null
        $curIndent = $Matches[1].Length
        if ($curIndent -le $envIndent) { $inBotEnv = $false }
      }

      # Rewrite API_BASE_URL if present in bot.environment
      if ($inBotEnv -and $line -match '^\s*API_BASE_URL:\s*') {
        $line = (" " * ($envIndent + 2)) + "API_BASE_URL: http://api:3001"
        $sawApiBase = $true
      }
    }

    $out.Add($line)

    # If bot starts, ensure restart exists early
    if ($inBot -and $line -match '^\s*bot:\s*$' -and -not $sawRestart) {
      $out.Add((" " * ($botIndent + 2)) + "restart: unless-stopped")
      $sawRestart = $true
    }
  }

  # If file ended while still inside bot
  if ($inBot) {
    if (-not $sawRestart) {
      $out.Add((" " * ($botIndent + 2)) + "restart: unless-stopped")
    }
    if (-not $sawDependsOn) {
      $out.Add((" " * ($botIndent + 2)) + "depends_on:")
      $out.Add((" " * ($botIndent + 4)) + "- api")
    }
    if ($inBotEnv -and -not $sawApiBase) {
      $out.Add((" " * ($envIndent + 2)) + "API_BASE_URL: http://api:3001")
    }
  }

  Set-Content $p -Value $out -Encoding UTF8
  Write-Host "docker-compose.yml updated (bot -> http://api:3001, restart, depends_on)"
}

function Fix-BotIndex() {
  $p = ".\bot\src\index.js"
  if (-not (Test-Path $p)) { throw "Missing bot/src/index.js" }
  Backup-File $p

  $c = Get-Content $p -Raw

  # Make Cloudflare detection specific (not any HTML)
  $c = $c -replace 'includes\("<html"\)', 'includes("cloudflare access")'
  $c = $c -replace "includes\('<html'\)", "includes('cloudflare access')"

  Set-Content $p -Value $c -Encoding UTF8
  Write-Host "bot/src/index.js updated (Cloudflare detection no longer false-positives)"
}

function Add-ApiBotEventsRoute() {
  # Try common server entrypoints
  $candidates = @(
    ".\api\src\index.js",
    ".\api\src\server.js",
    ".\api\src\app.js",
    ".\api\src\main.js"
  ) | Where-Object { Test-Path $_ }

  if ($candidates.Count -eq 0) {
    # last resort: find a file that contains app.listen and express()
    $found = Get-ChildItem ".\api\src" -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in ".js",".mjs",".cjs" } |
      Where-Object {
        $t = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        $t -and ($t -match "express\(") -and ($t -match "listen\(")
      } |
      Select-Object -First 1

    if ($found) { $candidates = @($found.FullName) }
  }

  if ($candidates.Count -eq 0) {
    Write-Host "WARNING: Could not locate API entrypoint automatically. Skipping API route patch."
    return
  }

  $p = $candidates[0]
  Backup-File $p

  $lines = Get-Content $p

  # If route already exists, do nothing
  if ($lines -match "/bot/events") {
    Write-Host "API already contains /bot/events somewhere. Skipping route insertion."
    return
  }

  $routeBlock = @(
    "",
    "// ---- Auto-added dev route for bot events ----",
    "app.post('/bot/events', (req, res) => {",
    "  // minimal dev handler so bot can post events locally",
    "  res.json({ ok: true, received: req.body ?? null });",
    "});",
    "// --------------------------------------------",
    ""
  )

  # Insert before the first app.listen(...) line
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  foreach ($line in $lines) {
    if (-not $inserted -and $line -match "app\.listen\s*\(") {
      foreach ($r in $routeBlock) { $out.Add($r) }
      $inserted = $true
    }
    $out.Add($line)
  }

  if (-not $inserted) {
    # If no app.listen, append to end
    foreach ($r in $routeBlock) { $out.Add($r) }
    $inserted = $true
  }

  Set-Content $p -Value $out -Encoding UTF8
  Write-Host "API patched: inserted POST /bot/events into $p"
}

Write-Host "== One-go fix starting =="

Fix-DockerCompose
Fix-BotIndex
Add-ApiBotEventsRoute

Write-Host ""
Write-Host "Restarting containers..."
docker compose down | Out-Null
docker compose up -d --build | Out-Null

Write-Host ""
docker compose ps

Write-Host ""
Write-Host "API check from bot network:"
docker compose run --rm bot sh -lc "wget -qO- http://api:3001" | Out-Host

Write-Host ""
Write-Host "POST /bot/events smoke test:"
docker compose run --rm bot sh -lc "wget -qO- --post-data='{\"test\":true}' --header='Content-Type: application/json' http://api:3001/bot/events" | Out-Host

Write-Host ""
Write-Host "Bot logs:"
docker compose logs --tail=120 bot
