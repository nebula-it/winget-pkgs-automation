# Prepare headers for auth
# Only create header if env var exists, this helps with local run where this does not exist
# And it is not usually required, we are using it here to avoid any API rate limits
if ($env:GITHUB_TOKEN) {
  $headers = @{
    Authorization = "Bearer $($env:GITHUB_TOKEN)"
  }
}

# Initialize Git
git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

$packages = Get-ChildItem .\packages\*.json -Exclude schema.json
foreach ($package in $packages) {
  $packageInfo = Get-Content -Raw $package | ConvertFrom-Json
  Write-Host "`n======== Working on Package $($packageInfo.Name) ========" -ForegroundColor Green
  # Get Latest version of Package releases
  $req = Invoke-RestMethod "https://api.github.com/repos/$($packageInfo.repoUrl)/releases/latest" -Headers $headers
  # Get Latest version number, remove `v` from string
  $latestVersion = $req.tag_name.Replace('v', '')
  # Once winget has support for tar.gz , add `|tar\.gz` to extension filter
  $downloadURLFilter = $package.downloadURLFilter ? $package.downloadURLFilter : '.*windows.*\.(zip|exe)$'
  # Get download url
  $latestVersionDownloadURL = $req.assets | Where-Object name -Match $downloadURLFilter | Select-Object -ExpandProperty browser_download_url

  # If the local manifest contains 'submittedVersion' we use that otherwise we get the latest version from winget
  if($packageInfo.submittedVersion){
    $wingetLatestVersion = $packageInfo.submittedVersion
    Write-Host "Retrived latest version $($wingetLatestVersion) from local manifest."
  }
  else {
    # Get contents of winget manifest e.g 'https://github.com/microsoft/winget-pkgs/tree/master/manifests/s/Sidero/talosctl'
    $wingetPackageList = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-pkgs/contents/$($packageInfo.wingetManifestPath)" -Headers $headers
    $wingetLatestVersion = $wingetPackageList | Select-Object -Last 1 | Select-Object -ExpandProperty name
    Write-Host "submittedVersion not found in local manifest. Retreived $($wingetLatestVersion) from wingt."
  }

  if ($latestVersion -ne $wingetLatestVersion) {
    Write-Host "Updating $($packageInfo.name) from '$wingetLatestVersion' to '$latestVersion'"
    $packageIdentifier = $packageInfo.packageIdentifier
    if (-not $packageIdentifier) {
      # If no $packageIdentifier is defined in packages manifest, we construct one using the wingetManifestPath. Where the second last 
      # subpath is org name and last bit of path is package name
      $packageIdentifier = "$(($packageInfo.wingetManifestPath).split('/')[-2]).$(($packageInfo.wingetManifestPath).split('/')[-1])"
    }
    $wingetCmd = ".\wingetcreate.exe update $packageIdentifier -s -v $latestVersion -u $($latestVersionDownloadURL -join (' '))" + ' -t $($env:WINGET_PAT)'
    Write-Host "Using cmd: $($wingetCmd)"
    # Download wingetcreate
    if (-not (Test-Path .\wingetcreate.exe)) {
      Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    }
    # Update the existing manifest
    # A bug with Invoke-Expression is not adding the output to wingetOutput var properly
    # using Tee-Object as workaround: https://stackoverflow.com/questions/37330115/invoke-expression-output-on-screen-and-in-a-variable
    Invoke-Expression $wingetCmd | Tee-Object -Variable wingetOutput 
    # First we get the lines that says 'Pull request can be found here:'
    # Then split it at Spaces and get the last string, which is URL
    Write-Debug "======== Start: Output of wingetCreate ============"
    Write-Debug $wingetOutput
    Write-Debug "======== End: Output of wingetCreate ============"
    $wingetPrURL = (($wingetOutput | Select-String -Pattern 'Pull request can be found here:\s+https:\/\/[\w\-\.\/]+').Matches[0] -split ' ')[-1]

    Write-Host "PR URL: $wingetPrURL"

    # If a PR is successfully submitted then update the local manifest 
    if ($wingetPrURL) {
      $packageInfo | Add-Member -MemberType NoteProperty -Name submittedVersion -Value $latestVersion
      $packageInfo | Add-Member -MemberType NoteProperty -Name submittedPrURL -Value $wingetPrURL
      $packageInfo | ConvertTo-Json | Set-Content -Path $package
      git add $package
      git commit -m "Updated $($packageInfo.name) to version $($latestVersion)"
      git push
    }

  }
  else {
    Write-Host "Latest version of $($packageInfo.name) ($($latestVersion))  is already present in Winget."
  }
}

