# Устанавливает пользовательскую команду dsh перед штатной в PATH.
# Для удаления из PATH повторно запустите сценарий с параметром -Uninstall.
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$destination = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'DevOS\dsh-cli-ru'
# Сохраняем исходные ссылки %SystemRoot% и тип значения Path в реестре.
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
try {
    $rawPath = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $parts = @($rawPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ine $destination })
    if (!$Uninstall) {
        $desktop = Get-Command dsh.cmd -All | Where-Object {
            Test-Path -LiteralPath (Join-Path (Split-Path $_.Source) '..\..\..\..\DeepSeek Harness.exe')
        } | Select-Object -First 1
        if (!$desktop) { throw 'Не найдена штатная команда dsh.cmd из DSH Desktop.' }
        $exe = (Resolve-Path (Join-Path (Split-Path $desktop.Source) '..\..\..\..\DeepSeek Harness.exe')).Path
        [void][IO.Directory]::CreateDirectory($destination)
        foreach ($file in 'dsh-cli-ru.cjs', 'dsh-cli-ru.json') {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $destination -Force
        }
        # Вычисляем относительный путь для cmd, чтобы имя профиля пользователя не попало в файл запуска.
        $baseUri = [Uri]($destination + '\')
        $relativeExe = [Uri]::UnescapeDataString($baseUri.MakeRelativeUri([Uri]$exe).ToString()).Replace('/', '\')
        if ([IO.Path]::IsPathRooted($relativeExe) -or $relativeExe -match '[^\x20-\x7E]|%') { throw 'Не удалось построить переносимый путь к DSH Desktop.' }
        $exeArg = "%~dp0$relativeExe"
        $entryArg = Join-Path (Split-Path $exeArg) 'resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js'
        $script = "@echo off`r`nsetlocal DisableDelayedExpansion`r`nset `"ELECTRON_RUN_AS_NODE=1`"`r`n`"$exeArg`" --expose-internals --require `"%~dp0dsh-cli-ru.cjs`" `"$entryArg`" %*`r`nexit /b %errorlevel%`r`n"
        [IO.File]::WriteAllText((Join-Path $destination 'dsh.cmd'), $script, [Text.Encoding]::ASCII)
        $parts = @($destination) + $parts
    }
    $kind = if ($key.GetValueNames() -contains 'Path') { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
    $key.SetValue('Path', ($parts -join ';'), $kind)
} finally { $key.Close() }
$rest = @($env:Path -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ine $destination })
if ($Uninstall) { $env:Path = $rest -join ';' } else { $env:Path = (@($destination) + $rest) -join ';' }

# Сообщаем Проводнику об изменении PATH для новых терминалов.
if (-not ('DevOS.CliEnvironment' -as [type])) {
    Add-Type -Namespace DevOS -Name CliEnvironment -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hwnd, uint message, System.UIntPtr wParam, string lParam, uint flags, uint timeout, out System.UIntPtr result);
"@
}
$result = [UIntPtr]::Zero
[void][DevOS.CliEnvironment]::SendMessageTimeout([IntPtr]0xffff, 0x001a, [UIntPtr]::Zero, 'Environment', 2, 1000, [ref]$result)
