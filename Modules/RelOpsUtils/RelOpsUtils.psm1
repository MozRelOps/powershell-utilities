function Download-Module {
  <#
  .Synopsis
    Downloads a psm1 module file to the local modules folder
  .Description
    The local module will use the psm1 filename, minus extension, as the module name
  .Parameter url
    The full url to the userdata module.
  .Parameter modulesPath
    The full path to the local modules folder.
  #>
  param (
    [string] $url,
    [string] $modulesPath = ('{0}\Modules' -f $pshome)
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    $filename = $url.Substring($url.LastIndexOf('/') + 1)
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($filename)
    New-Item -ItemType Directory -Force -Path ('{0}\{1}' -f $modulesPath, $moduleName)
    (New-Object Net.WebClient).DownloadFile($url, ('{0}\{1}\{2}' -f $modulesPath, $moduleName, $filename))
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Install-Mercurial {
  param (
    [string] $url = 'http://mercurial.selenic.com/release/windows/Mercurial-3.5.1-x64.exe',
    [string] $installer = [IO.Path]::Combine($env:TEMP, $url.Substring($url.LastIndexOf('/') + 1)),
    [string] $path = [IO.Path]::Combine($env:SystemDrive, 'mozilla-build', 'hg'),
    [string] $log = [IO.Path]::Combine($env:SystemDrive, 'log', 'hg-install.log')
  )
  (New-Object Net.WebClient).DownloadFile($url, $installer)
  $installArgs = @('/SP-', '/VerySilent', '/SUPPRESSMSGBOXES', ('/DIR={0}' -f $path), ('/LOG={0}' -f $log))
  & $installer $installArgs
}

function Install-BundleClone {
  param (
    [string] $url = 'https://hg.mozilla.org/hgcustom/version-control-tools/raw-file/default/hgext/bundleclone/__init__.py',
    [string] $path = [IO.Path]::Combine($env:SystemDrive, 'mozilla-build', 'hg'),
    [string] $filename = 'bundleclone.py',
    [string] $hgrc = [IO.Path]::Combine($env:USERPROFILE, '.hgrc')
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    if (Test-Path $path) {
      $target = [IO.Path]::Combine($path, $filename)
      if (Test-Path $target) {
        Remove-Item -path $target -force
      }
      Write-Log -message ('installing latest bundleclone to: {0}' -f $target) -severity 'INFO'
      (New-Object Net.WebClient).DownloadFile($url, $target)
      Enable-BundleClone -hgrc $hgrc -path $target
    }
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Enable-BundleClone {
  param (
    [string] $hgrc = [IO.Path]::Combine($env:USERPROFILE, '.hgrc'),
    [string] $path = [IO.Path]::Combine($env:SystemDrive, 'mozilla-build', 'hg', 'bundleclone.py')
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    if (Test-Path $hgrc) {
      Write-Log -message ("{0} :: detected hgrc at: {1}" -f $($MyInvocation.MyCommand.Name), $hgrc) -severity 'DEBUG'
      $config = Get-IniContent $hgrc
      if (-not $config.ContainsKey('extensions')) {
        $config.Add('extensions', @{})
        Write-Log -message ("{0} :: created new [extensions] section" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      } else {
        Write-Log -message ("{0} :: detected existing [extensions] section" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      }
      if (-not $config['extensions'].ContainsKey('bundleclone')) {
        Write-Log -message ("{0} :: detected bundleclone extension not enabled." -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        try {
          $config['extensions'].Add('bundleclone', $path)
          Out-IniFile $config $hgrc
          Write-Log -message ("{0} :: enabled bundleclone extension." -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        } catch {
          Write-Log -message ("{0} :: failed to enable bundleclone extension. {1}" -f $($MyInvocation.MyCommand.Name), $_.Exception) -severity 'ERROR'
        }
      } else {
        Write-Log -message ("{0} :: detected enabled bundleclone extension with path: {1}." -f $($MyInvocation.MyCommand.Name), $config['extensions']['bundleclone']) -severity 'DEBUG'
        if ($config['extensions']['bundleclone'] -ne $path) {
          try {
            $config['extensions'].Set_Item('bundleclone', $path)
            Out-IniFile $config $hgrc
            Write-Log -message ("{0} :: set bundleclone path to: {1}." -f $($MyInvocation.MyCommand.Name), $path) -severity 'INFO'
          } catch {
            Write-Log -message ("{0} :: failed to set bundleclone path to: {1}. {2}" -f $($MyInvocation.MyCommand.Name), $path, $_.Exception) -severity 'ERROR'
          }
        }
      }
    }
    if (Test-Path $hgrc) {
      Write-Log -message "enabling bundleclone" -severity 'INFO'
      (Get-Content $hgrc) | foreach-Object { $_ -replace "#bundleclone(\s*)?=.*$", "bundleclone=$path" } | Set-Content $hgrc
    }
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Disable-BundleClone {
  param (
    [string] $hgrc = [IO.Path]::Combine($env:USERPROFILE, '.hgrc')
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    if (Test-Path $hgrc) {
      Write-Log -message ("{0} :: detected hgrc at: {1}" -f $($MyInvocation.MyCommand.Name), $hgrc) -severity 'DEBUG'
      $config = Get-IniContent $hgrc
      if ($config.ContainsKey('extensions')) {
        Write-Log -message ("{0} :: detected extension section" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        if ($config['extensions'].ContainsKey('bundleclone')) {
          Write-Log -message ("{0} :: detected enabled bundleclone extension" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          try {
            $config['extensions'].Remove('bundleclone')
            Out-IniFile $config $hgrc
          } catch {
            Write-Log -message ("{0} :: failed to disable bundleclone extension. {1}" -f $($MyInvocation.MyCommand.Name), $_.Exception) -severity 'ERROR'
          }
        }
      }
    }
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Get-IniContent {
  <#
  .Synopsis
    Gets the content of an INI file
  .Description
    Gets the content of an INI file and returns it as a hashtable
  .Notes
    Author      : Oliver Lipkau <oliver@lipkau.net>
    Blog        : http://oliver.lipkau.net/blog/
    Source      : https://github.com/lipkau/PsIni
                  http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
    Version     : 1.0 - 2010/03/12 - Initial release
                  1.1 - 2014/12/11 - Typo (Thx SLDR)
                                     Typo (Thx Dave Stiff)
    #Requires -Version 2.0
  .Inputs
    System.String
  .Outputs
    System.Collections.Hashtable
  .Parameter FilePath
    Specifies the path to the input file.
  .Example
    $FileContent = Get-IniContent "C:\myinifile.ini"
    -----------
    Description
    Saves the content of the c:\myinifile.ini in a hashtable called $FileContent
  .Example
    $inifilepath | $FileContent = Get-IniContent
    -----------
    Description
    Gets the content of the ini file passed through the pipe into a hashtable called $FileContent
  .Example
    C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
    C:\PS>$FileContent["Section"]["Key"]
    -----------
    Description
    Returns the key "Key" of the section "Section" from the C:\settings.ini file
  .Link
    Out-IniFile
  #>
  [CmdletBinding()]
  Param (
    [ValidateNotNullOrEmpty()]
    [ValidateScript({(Test-Path $_)})]
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
    [string]$FilePath
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    Write-Log -message ("{0} :: Parsing file: {1}" -f $($MyInvocation.MyCommand.Name), $Filepath) -severity 'DEBUG'
    $ini = @{}
    switch -regex -file $FilePath {
      # Section
      "^\[(.+)\]$" {
        $section = $matches[1]
        $ini[$section] = @{}
        $CommentCount = 0
      }
      # Comment
      "^(;.*)$" {
        if (!($section)) {
            $section = "No-Section"
            $ini[$section] = @{}
        }
        $value = $matches[1]
        $CommentCount = $CommentCount + 1
        $name = "Comment" + $CommentCount
        $ini[$section][$name] = $value
      }
      # Key
      "(.+?)\s*=\s*(.*)" {
        if (!($section)) {
          $section = "No-Section"
          $ini[$section] = @{}
        }
        $name,$value = $matches[1..2]
        $ini[$section][$name] = $value
      }
    }
    Write-Log -message ("{0} :: Finished parsing file: {1}" -f $($MyInvocation.MyCommand.Name), $Filepath) -severity 'DEBUG'
    Return $ini
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Out-IniFile {
  <#
  .Synopsis
    Write hash content to INI file
  .Description
    Write hash content to INI file
  .Notes
    Author      : Oliver Lipkau <oliver@lipkau.net>
    Blog        : http://oliver.lipkau.net/blog/
    Source      : https://github.com/lipkau/PsIni
                  http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
    Version     : 1.0 - 2010/03/12 - Initial release
                  1.1 - 2012/04/19 - Bugfix/Added example to help (Thx Ingmar Verheij)
                  1.2 - 2014/12/11 - Improved handling for missing output file (Thx SLDR)
    #Requires -Version 2.0
  .Inputs
    System.String
    System.Collections.Hashtable
  .Outputs
    System.IO.FileSystemInfo
  .Parameter Append
    Adds the output to the end of an existing file, instead of replacing the file contents.
  .Parameter InputObject
    Specifies the Hashtable to be written to the file. Enter a variable that contains the objects or type a command or expression that gets the objects.
  .Parameter FilePath
    Specifies the path to the output file.
  .Parameter Encoding
    Specifies the type of character encoding used in the file. Valid values are "Unicode", "UTF7", "UTF8", "UTF32", "ASCII", "BigEndianUnicode", "Default", and "OEM". "Unicode" is the default.
    "Default" uses the encoding of the system's current ANSI code page.
    "OEM" uses the current original equipment manufacturer code page identifier for the operating system.
  .Parameter Force
    Allows the cmdlet to overwrite an existing read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.
  .Parameter PassThru
    Passes an object representing the location to the pipeline. By default, this cmdlet does not generate any output.
  .Example
    Out-IniFile $IniVar "C:\myinifile.ini"
    -----------
    Description
    Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini
  .Example
    $IniVar | Out-IniFile "C:\myinifile.ini" -Force
    -----------
    Description
    Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and overwrites the file if it is already present
  .Example
    $file = Out-IniFile $IniVar "C:\myinifile.ini" -PassThru
    -----------
    Description
    Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and saves the file into $file
  .Example
    $Category1 = @{“Key1”=”Value1”;”Key2”=”Value2”}
    $Category2 = @{“Key1”=”Value1”;”Key2”=”Value2”}
    $NewINIContent = @{“Category1”=$Category1;”Category2”=$Category2}
    Out-IniFile -InputObject $NewINIContent -FilePath "C:\MyNewFile.INI"
    -----------
    Description
    Creating a custom Hashtable and saving it to C:\MyNewFile.INI
  .Link
    Get-IniContent
  #>
  [CmdletBinding()]
  Param (
    [switch]$Append,

    [ValidateSet("Unicode","UTF7","UTF8","UTF32","ASCII","BigEndianUnicode","Default","OEM")]
    [Parameter()]
    [string]$Encoding = "Unicode",

    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^([a-zA-Z]\:)?.+\.ini$')]
    [Parameter(Mandatory=$True)]
    [string]$FilePath,

    [switch]$Force,

    [ValidateNotNullOrEmpty()]
    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
    [Hashtable]$InputObject,

    [switch]$Passthru
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    Write-Log -message ("{0} :: Writing file: {1}" -f $($MyInvocation.MyCommand.Name), $Filepath) -severity 'DEBUG'
    if ($append) {
      $outfile = Get-Item $FilePath
    } else {
      $outFile = New-Item -ItemType file -Path $Filepath -Force:$Force
    }
    if (!($outFile)) {
      throw "Could not create File"
    }
    foreach ($i in $InputObject.keys) {
      if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
        #No Sections
        Write-Log -message ("{0} :: Writing key: {1}" -f $($MyInvocation.MyCommand.Name), $i) -severity 'DEBUG'
        Add-Content -Path $outFile -Value "$i=$($InputObject[$i])" -Encoding $Encoding
      } else {
        #Sections
        Write-Log -message ("{0} :: Writing section: [{1}]" -f $($MyInvocation.MyCommand.Name), $i) -severity 'DEBUG'
        Add-Content -Path $outFile -Value "[$i]" -Encoding $Encoding
        foreach ($j in $($InputObject[$i].keys | Sort-Object)) {
          if ($j -match "^Comment[\d]+") {
            Write-Log -message ("{0} :: Writing comment: {1}" -f $($MyInvocation.MyCommand.Name), $j) -severity 'DEBUG'
            Add-Content -Path $outFile -Value "$($InputObject[$i][$j])" -Encoding $Encoding
          } else {
            Write-Log -message ("{0} :: Writing key: {1}" -f $($MyInvocation.MyCommand.Name), $j) -severity 'DEBUG'
            Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])" -Encoding $Encoding
          }
        }
        Add-Content -Path $outFile -Value "" -Encoding $Encoding
      }
    }
    Write-Log -message ("{0} :: Finished writing file: {1}" -f $($MyInvocation.MyCommand.Name), $Filepath) -severity 'DEBUG'
    if ($PassThru) {
      Return $outFile
    }
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}
