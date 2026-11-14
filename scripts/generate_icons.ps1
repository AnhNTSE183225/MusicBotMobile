$root = Split-Path -Parent $PSScriptRoot
$flutterBin = Join-Path $env:USERPROFILE "flutter\bin"
$env:Path = "$flutterBin;$env:Path"
Set-Location $root
flutter test scripts/generate_icons_test.dart
