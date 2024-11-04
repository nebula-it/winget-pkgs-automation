# Prepare headers for auth
$headers = @{
  Authorization = "Bearer $($env:GITHUB_TOKEN)"
}

$packages = Get-ChildItem .\packages -Exclude schema.json
foreach ($package in $packages) {
  $packageInfo = Get-Content -Raw $package | ConvertFrom-Json
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
  if (-not $packageIdentifier){
    $packageIdentifier = "$(($packageInfo.wingetManifestPath).split('/')[-2]).$(($packageInfo.wingetManifestPath).split('/')[-1])"
  }
  if ($latestVersion -ne $wingetLatestVersion) {
    Write-Host "Updating $($packageInfo.name) from '$wingetLatestVersion' to '$latestVersion'"
    # Download wingetcreate
    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe

    # Update the existing manifest
    .\wingetcreate.exe update $packageIdentifier -s -v $latestVersion -u $($latestVersionDownloadURL -join (' ')) -t $($env:WINGET_PAT)
  }
  else {
    Write-Host "Latest version of $($packageInfo.name) ($($latestVersion))  is already present in Winget."
  }
}

