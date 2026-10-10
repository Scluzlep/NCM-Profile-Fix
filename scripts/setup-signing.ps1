# Run once in PowerShell. Requires Java keytool and GitHub CLI (gh).
# Keystore and backup file stay OUTSIDE the Git repository.
$ErrorActionPreference = "Stop"
$repo = "Scluzlep/NCM-Profile-Fix"
$dir = Join-Path $HOME "NCM-Profile-Fix-Signing"
$keystore = Join-Path $dir "release.p12"
$backup = Join-Path $dir "release-credentials.txt"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is missing: https://cli.github.com/"
}
$keytoolCmd = Get-Command keytool -ErrorAction SilentlyContinue
$keytoolExe = if ($keytoolCmd) { $keytoolCmd.Source } else { $null }
if (-not $keytoolExe -and $env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path $candidate) { $keytoolExe = $candidate }
}
if (-not $keytoolExe) {
    throw "Java keytool is missing. Install JDK 17 or set JAVA_HOME."
}

& gh auth status
if ($LASTEXITCODE -ne 0) { throw "Please run: gh auth login" }

if ((Test-Path $keystore) -or (Test-Path $backup)) {
    throw "Existing signing material found in $dir. Do not regenerate keys. Reuse the original certificate for future releases."
}
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$pass = [BitConverter]::ToString($bytes).Replace("-", "").ToLowerInvariant()
$alias = "ncm-profile-fix"

& $keytoolExe -genkeypair -keystore $keystore -storetype PKCS12 `
  -alias $alias -keyalg RSA -keysize 3072 -validity 36500 `
  -storepass $pass -keypass $pass `
  -dname "CN=NCM Profile Fix, OU=Android, O=Scluzlep, C=US" -noprompt
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keystore)) {
    throw "Key generation failed; no Secrets uploaded."
}

$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
# GitHub encrypts repository Secrets. --body ensures no newline is part of a password.
& gh secret set KEYSTORE_BASE64 --body $base64 --repo $repo
if ($LASTEXITCODE -ne 0) { throw "Failed to set KEYSTORE_BASE64" }
& gh secret set KEYSTORE_PASSWORD --body $pass --repo $repo
if ($LASTEXITCODE -ne 0) { throw "Failed to set KEYSTORE_PASSWORD" }
& gh secret set KEY_PASSWORD --body $pass --repo $repo
if ($LASTEXITCODE -ne 0) { throw "Failed to set KEY_PASSWORD" }
& gh secret set KEY_ALIAS --body $alias --repo $repo
if ($LASTEXITCODE -ne 0) { throw "Failed to set KEY_ALIAS" }

@"
Keystore: $keystore
Alias: $alias
Password: $pass
"@ | Set-Content -Path $backup -Encoding utf8

Write-Host "Configured four GitHub Actions Secrets for $repo"
Write-Host "BACK UP THESE TWO FILES SECURELY (keep them private):"
Write-Host "  $keystore"
Write-Host "  $backup"
Write-Host "For the first release, push git tag v0.1.0."
