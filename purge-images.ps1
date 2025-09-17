# --- configure ---
$acrName = "acrsharedservicesdev"                 # e.g. myregistry
$acrFqdn = "$($acrName).azurecr.io"

$aksName = "aks-sharedservices-dev-01"
$aksResourceGroup = "rg-sharedservices-dev-01"
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
