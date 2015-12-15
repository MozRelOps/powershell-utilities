function Run-DesiredStateConfig {
  param (
    [string] $url
  )
  $config = [IO.Path]::GetFileNameWithoutExtension($url)
  $target = ('{0}\{1}.ps1' -f $env:Temp, $config)
  (New-Object Net.WebClient).DownloadFile($url, $target)
  Unblock-File -Path $target
  . $target
  $mof = ('{0}\{1}' -f $env:Temp, $config)
  & $config @('-OutputPath', $mof)
  Start-DscConfiguration -Path $mof -Wait -Verbose -Force
}

$moztype = 'y-2012'

$manifestUri = ('https://raw.githubusercontent.com/MozRelOps/powershell-utilities/master/Manifest/{0}' -f $moztype)
$configs = @(
  'ResourceConfig',
  'ServiceConfig',
  'SoftwareConfig'
)
foreach ($config in $configs) {
  Run-DesiredStateConfig -url ('{0}/{1}.ps1' -f $manifestUri, $config)
}
