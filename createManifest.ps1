# Prepare headers for auth
# Only create header if env var exists, this helps with local run where this does not exist
# And it is not usually required, we are using it here to avoid any API rate limits
if ($env:GITHUB_TOKEN) {
  $headers = @{
    Authorization = "Bearer $($env:GITHUB_TOKEN)"
  }
}

$packages = Get-ChildItem .\packages\*.json -Exclude schema.json
foreach ($package in $packages) {
  $packageInfo = Get-Content -Raw $package | ConvertFrom-Json
  Write-Host "`n======== Working on Package $($packageInfo.Name) ========" -ForegroundColor Green
  # Get Latest version of Package releases
  $req = Invoke-RestMethod "https://api.github.com/repos/$($packageInfo.repoUrl)/releases/latest" -Headers $headers
  # Get Latest version number, remove `v` from string
  $latestVersion = $req.tag_name.Replace('v', '')
  # Get download url for windows exe or zip files
  $latestVersionDownloadURL = $req.assets | Where-Object name -Like '*windows*[zip|exe]' | Select-Object -ExpandProperty browser_download_url

  # Get contents of 'https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/Sidero/talosctl'
  $wingetPackageList = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-pkgs/contents/$($packageInfo.wingetManifestPath)" -Headers $headers

  # Get latest version of package on Winget 
  $wingetLatestVersion = $wingetPackageList | Select-Object -Last 1 | Select-Object -ExpandProperty name

  $packageIdentifier = $packageInfo.packageIdentifier
  if (-not $packageIdentifier) {
    # If no $packageIdentifier is defined in packages manifest, we construct one using the wingetManifestPath. Where the second last 
    # subpath is org name and last bit of path is package name
    $packageIdentifier = "$(($packageInfo.wingetManifestPath).split('/')[-2]).$(($packageInfo.wingetManifestPath).split('/')[-1])"
  }
  if ($latestVersion -ne $wingetLatestVersion) {
    Write-Host "Updating $($packageInfo.name) from '$wingetLatestVersion' to '$latestVersion'"
    $wingetCmd = ".\wingetcreate.exe update $packageIdentifier -s -v $latestVersion -u $($latestVersionDownloadURL -join (' '))" + ' -t $($env:WINGET_PAT)'
    Write-Host "Using cmd: $($wingetCmd)"
    # Download wingetcreate
    if (-not (Test-Path .\wingetcreate.exe)) {
      Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    }
    # Update the existing manifest
    Invoke-Expression $wingetCmd -Verbose
  }
  else {
    Write-Host "Latest version of $($packageInfo.name) ($($latestVersion))  is already present in Winget."
  }
}

