# --- configure ---
$acrName = $env:ACR_NAME                 # e.g. myregistry
$acrFqdn = "$($acrName).azurecr.io"

$aksName = $env:AKS_NAME
$aksResourceGroup = $env:AKS_RESOURCE_GROUP

# ToDo: login on az cli
# ToDo: login on az cli using system managed identity
az login --identity
# Get AKS credentials. Use --admin if your MI/SP lacks cluster user role powershell
az aks get-credentials --overwrite-existing --name $aksName --resource-group $aksResourceGroup
# ToDo: get k8s pairs
$k8sPairs = kubectl get pods -A -o json |
  ConvertFrom-Json |
  Select-Object -ExpandProperty items |
  ForEach-Object {
    @(
      if ($_.spec.containers)          { $_.spec.containers.image }
      if ($_.spec.initContainers)      { $_.spec.initContainers.image }
      if ($_.spec.ephemeralContainers) { $_.spec.ephemeralContainers.image }
    )
  } |
  Where-Object { $_ } |
  Where-Object { $_ -like "$acrFqdn/*" } |
  ForEach-Object {
    $img = $_.Substring($acrFqdn.Length + 1)     # strip registry prefix
    $lastColon = $img.LastIndexOf(":")
    $lastSlash = $img.LastIndexOf("/")
    if ($lastColon -gt $lastSlash -and $lastColon -ge 0) {
      "$($img.Substring(0,$lastColon)):$($img.Substring($lastColon+1))"
    } else {
      "$img:latest"
    }
  } |
  Sort-Object -Unique

$k8sPairs | Format-Table -AutoSize

$allTop4Tags = @() # Top4 tags
$allTags = @() # All tags
# ToDo: retry logic for $acrImages
try {
  $acrImages = az acr repository list --name $acrName --output tsv
} catch {
  Write-Warning "Error getting acr images. Retrying..."
  az login --identity
  $acrImages = az acr repository list --name $acrName --output tsv
}

foreach ($repo in $acrImages) {
    $top4 = az acr repository show-tags --name $acrName --repository $repo --orderby time_asc --top 4 --output tsv
    $all = az acr repository show-tags --name $acrName --repository $repo --output tsv
    foreach ($tag in $top4) {
        $allTop4Tags += "$($repo):$($tag)"
    }
    foreach ($tag in $all) {
        $allTags += "$($repo):$($tag)"
    }
}

# get all the repos in the $k8sPairs
$k8sPairsRepos = $k8sPairs | ForEach-Object {
    $repo = $_
    $repo = $repo.Split(":")[0]
    $repo
}

# for each tagsInAcr, check if the tag is in the k8sPairs
$allTop3Tags = @()
foreach ($tag in $allTop4Tags) {
    if ($tag.Split(":")[0] -in $k8sPairsRepos) {
        if ($tag -notin $k8sPairs) {
            $allTop3Tags += $tag
        }
    }
}

$unusedTags = @()
foreach ($tag in $allTags) {
    if ($tag -notin $allTop3Tags -and $tag -notin $k8sPairs) {
        $unusedTags += $tag
    }
}
#remove image name pwsh-purge-task from the unusedTags
$unusedTags = $unusedTags | Where-Object { $_ -ne "pwsh-purge-task:latest" }
# log the unusedTags
$unusedTags | Format-Table -AutoSize

# ToDo: delelte the unusedTags from the acr
foreach ($unusedTag in $unusedTags) {
    az acr repository delete --name $acrName --image $unusedTag --yes
    Write-Host "Deleted $unusedTag"
}
