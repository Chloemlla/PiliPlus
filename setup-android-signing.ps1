param()

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Host '[错误] 请使用 PowerShell 7 或更高版本运行此脚本。' -ForegroundColor Red
  Write-Host '       示例: pwsh -File .\setup-android-signing.ps1'
  exit 1
}

function Write-Section {
  param([string]$Message)

  Write-Host ''
  Write-Host $Message
}

function Write-Success {
  param([string]$Message)

  Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-WarningMessage {
  param([string]$Message)

  Write-Host "[警告] $Message" -ForegroundColor Yellow
}

function Stop-WithError {
  param([string]$Message)

  Write-Host "[错误] $Message" -ForegroundColor Red
  Pause-ForUser
  exit 1
}

function Pause-ForUser {
  Write-Host ''
  Read-Host '按 Enter 键继续' | Out-Null
}

function Get-PlainText {
  param([System.Security.SecureString]$SecureString)

  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
  try {
    [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Test-NativeCommand {
  param(
    [string]$Command,
    [string[]]$Arguments
  )

  & $Command @Arguments *> $null
  return $LASTEXITCODE -eq 0
}

function Set-GitHubSecret {
  param(
    [string]$GhCommand,
    [string]$Repo,
    [string]$Name,
    [string]$Value
  )

  $Value | & $GhCommand secret set $Name --repo $Repo
  return $LASTEXITCODE -eq 0
}

Write-Host ''
Write-Host '========================================'
Write-Host '  piliplus Android 签名配置'
Write-Host '========================================'
Write-Host ''

Write-Host '[1/6] 检查依赖工具...'

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
  Stop-WithError '未找到 keytool，请安装 JDK 并添加到 PATH。下载地址: https://www.oracle.com/java/technologies/downloads/'
}
Write-Success 'keytool 已安装'

$ghCommand = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $ghCommand) {
  Write-WarningMessage '在 PATH 中未找到 gh 命令'
  Write-Host ''
  Write-Host '正在检查常见安装位置...'

  $ghCandidates = @(
    'D:\Program Files\GitHub CLI\gh.exe',
    'D:\Program Files (x86)\GitHub CLI\gh.exe',
    "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe",
    "$env:ProgramFiles\gh\gh.exe"
  )

  $ghCommand = $ghCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
  if (-not $ghCommand) {
    Write-Host '[错误] 未找到 GitHub CLI 安装' -ForegroundColor Red
    Write-Host ''
    Write-Host '请执行以下操作之一:'
    Write-Host '  1. 下载并安装: https://cli.github.com/'
    Write-Host '  2. 使用 winget 安装: winget install --id GitHub.cli'
    Write-Host '  3. 使用 scoop 安装: scoop install gh'
    Write-Host '  4. 安装后重启终端或添加到 PATH'
    Pause-ForUser
    exit 1
  }

  Write-Success "找到 GitHub CLI: $ghCommand"
  Write-Host '  提示: 建议将 GitHub CLI 添加到 PATH 环境变量'
} else {
  Write-Success 'GitHub CLI 已安装'
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Stop-WithError '未找到 git，无法在 gh repo view 失败时解析 remote。'
}
Write-Success 'git 可用'
Write-Success "PowerShell $($PSVersionTable.PSVersion) 可用"

Write-Section '[2/6] 检查 GitHub 登录状态...'

if ($env:GH_TOKEN) {
  Write-Success '检测到 GH_TOKEN 环境变量'
  if (-not (Test-NativeCommand -Command $ghCommand -Arguments @('auth', 'status'))) {
    Write-Host '[错误] GH_TOKEN 无效或已过期' -ForegroundColor Red
    Write-Host ''
    Write-Host '请执行以下操作之一:'
    Write-Host '  1. 清除环境变量后重新登录:'
    Write-Host '     Remove-Item Env:\GH_TOKEN'
    Write-Host '     gh auth login'
    Write-Host ''
    Write-Host '  2. 更新 GH_TOKEN 为有效的 Personal Access Token'
    Write-Host '     创建地址: https://github.com/settings/tokens'
    Pause-ForUser
    exit 1
  }
  Write-Success '已通过 GH_TOKEN 认证'
} else {
  if (-not (Test-NativeCommand -Command $ghCommand -Arguments @('auth', 'status'))) {
    Write-Host '[错误] 未登录 GitHub CLI' -ForegroundColor Red
    Write-Host ''
    Write-Host '请先运行以下命令登录:'
    Write-Host "  `"$ghCommand`" auth login"
    Write-Host ''
    Write-Host '然后选择:'
    Write-Host '  1. GitHub.com'
    Write-Host '  2. HTTPS 协议'
    Write-Host '  3. Login with a web browser'
    Pause-ForUser
    exit 1
  }
  Write-Success '已登录 GitHub'
}

Write-Section '[3/6] 检测 GitHub 仓库...'

$repo = $null
$repoOutput = & $ghCommand repo view --json nameWithOwner -q .nameWithOwner 2>$null
if ($LASTEXITCODE -eq 0) {
  $repo = ($repoOutput | Select-Object -First 1).Trim()
}

if (-not $repo) {
  Write-Host '  方法1失败，尝试从 git remote 解析...'
  $remoteUrl = & git config --get remote.origin.url 2>$null
  if ($LASTEXITCODE -eq 0 -and $remoteUrl) {
    $remoteUrl = ($remoteUrl | Select-Object -First 1).Trim()
    if ($remoteUrl -match 'github\.com[:/](?<repo>[^/]+/[^/]+?)(?:\.git)?$') {
      $repo = $Matches.repo
    }
  }
}

if (-not $repo) {
  Write-Host '[错误] 无法检测到 GitHub 仓库' -ForegroundColor Red
  Write-Host ''
  Write-Host '请确保:'
  Write-Host '  1. 当前目录是 git 仓库'
  Write-Host '  2. 仓库已关联 GitHub remote'
  Write-Host '  3. 已推送到 GitHub'
  Write-Host ''
  Write-Host '调试信息:'
  & git remote -v
  Pause-ForUser
  exit 1
}
Write-Success "检测到仓库: $repo"

Write-Section '[4/6] 配置签名参数...'
Write-Host ''

$keystoreFile = 'piliplus-release.jks'
$keyAlias = 'piliplus'
$dname = 'CN=piliplus, OU=Dev, O=piliplus, L=Unknown, ST=Unknown, C=US'

Write-Host '请输入 keystore 密码（至少 6 位）:'
$storeSecurePassword = Read-Host '> ' -AsSecureString
$storePassword = Get-PlainText $storeSecurePassword
if ([string]::IsNullOrWhiteSpace($storePassword) -or $storePassword.Length -lt 6) {
  Stop-WithError 'keystore 密码不能为空，且长度至少为 6 位。'
}

Write-Host ''
Write-Host '请输入 key 密码（直接回车则使用与 keystore 相同的密码）:'
$keySecurePassword = Read-Host '> ' -AsSecureString
$keyPassword = Get-PlainText $keySecurePassword
if ([string]::IsNullOrWhiteSpace($keyPassword)) {
  $keyPassword = $storePassword
}

Write-Section '[5/6] 生成 keystore 文件...'

if (Test-Path -LiteralPath $keystoreFile) {
  Write-WarningMessage "$keystoreFile 已存在，备份为 $keystoreFile.bak"
  Copy-Item -LiteralPath $keystoreFile -Destination "$keystoreFile.bak" -Force
}

& keytool -genkeypair `
  -v `
  -keystore $keystoreFile `
  -alias $keyAlias `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname $dname

if ($LASTEXITCODE -ne 0) {
  Stop-WithError '生成 keystore 失败'
}

Write-Success "Keystore 生成成功: $keystoreFile"

Write-Host ''
Write-Host '  正在编码为 Base64...'
$base64File = 'keystore_base64.txt'
$keystoreBytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $keystoreFile).Path)
$keystoreBase64 = [System.Convert]::ToBase64String($keystoreBytes)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $base64File), $keystoreBase64, $utf8NoBom)

if ([string]::IsNullOrWhiteSpace($keystoreBase64)) {
  Stop-WithError 'Base64 内容为空'
}

$previewLength = [Math]::Min(50, $keystoreBase64.Length)
Write-Success "Base64 编码完成 (长度: $($keystoreBase64.Length), 预览: $($keystoreBase64.Substring(0, $previewLength))...)"

Write-Section '[6/6] 准备设置 GitHub Secrets...'
Write-Host ''
Write-Host '========================================'
Write-Host '  即将推送以下变量到远程仓库'
Write-Host '========================================'
Write-Host ''
Write-Host "仓库: $repo"
Write-Host ''
Write-Host '变量列表:'
Write-Host '  1. KEYSTORE_BASE64'
Write-Host "     长度: $((Get-Item -LiteralPath $base64File).Length) 字符"
Write-Host '     值: [已隐藏]'
Write-Host ''
Write-Host '  2. KEYSTORE_PASSWORD'
Write-Host '     值: [已隐藏]'
Write-Host ''
Write-Host '  3. KEY_ALIAS'
Write-Host "     值: $keyAlias"
Write-Host ''
Write-Host '  4. KEY_PASSWORD'
Write-Host '     值: [已隐藏]'
Write-Host ''
Write-Host '========================================'
Write-Host ''
Write-WarningMessage '这些敏感信息将被推送到 GitHub Secrets'
Write-Host '       请确认以上信息正确无误'
Write-Host ''
$confirm = Read-Host '确认推送? (输入 YES 继续)'

if ($confirm -cne 'YES') {
  Write-Host ''
  Write-Host '[已取消] 未推送任何变量'
  Pause-ForUser
  exit 0
}

Write-Host ''
Write-Host '开始推送变量...'
Write-Host ''

Write-Host '  设置 KEYSTORE_BASE64...'
if (-not (Set-GitHubSecret -GhCommand $ghCommand -Repo $repo -Name 'KEYSTORE_BASE64' -Value $keystoreBase64)) {
  Stop-WithError '设置 KEYSTORE_BASE64 失败'
}
Write-Success 'KEYSTORE_BASE64'

Write-Host '  设置 KEYSTORE_PASSWORD...'
if (-not (Set-GitHubSecret -GhCommand $ghCommand -Repo $repo -Name 'KEYSTORE_PASSWORD' -Value $storePassword)) {
  Stop-WithError '设置 KEYSTORE_PASSWORD 失败'
}
Write-Success 'KEYSTORE_PASSWORD'

Write-Host '  设置 KEY_ALIAS...'
if (-not (Set-GitHubSecret -GhCommand $ghCommand -Repo $repo -Name 'KEY_ALIAS' -Value $keyAlias)) {
  Stop-WithError '设置 KEY_ALIAS 失败'
}
Write-Success 'KEY_ALIAS'

Write-Host '  设置 KEY_PASSWORD...'
if (-not (Set-GitHubSecret -GhCommand $ghCommand -Repo $repo -Name 'KEY_PASSWORD' -Value $keyPassword)) {
  Stop-WithError '设置 KEY_PASSWORD 失败'
}
Write-Success 'KEY_PASSWORD'

Write-Host ''
Write-Host '========================================'
Write-Host '  配置完成！'
Write-Host '========================================'
Write-Host ''
Write-Host "Keystore 文件: $keystoreFile"
Write-Host "Key 别名     : $keyAlias"
Write-Host ''
Write-Host "已在 $repo 设置以下 GitHub Secrets:"
Write-Success 'KEYSTORE_BASE64'
Write-Success 'KEYSTORE_PASSWORD'
Write-Success 'KEY_ALIAS'
Write-Success 'KEY_PASSWORD'
Write-Host ''
Write-Host '[重要提示]'
Write-Host "  1. 请妥善保管 $keystoreFile 文件并备份"
Write-Host '  2. 该文件已在 .gitignore 中，不会被提交到 git'
Write-Host '  3. 现在可以运行 GitHub Actions 构建签名的 APK/AAB'
Write-Host "  4. 临时文件 $base64File 已生成，可以手动删除"
Write-Host ''

if (Test-Path -LiteralPath $base64File) {
  $deleteTemp = Read-Host '是否删除临时 Base64 文件? (Y/N)'
  if ($deleteTemp -ieq 'Y') {
    Remove-Item -LiteralPath $base64File -Force
    Write-Success "已删除 $base64File"
  }
}

Pause-ForUser
