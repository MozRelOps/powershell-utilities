function Install-Mercurial {
  param (
    [string] $url = 'http://mercurial.selenic.com/release/windows/Mercurial-3.5.1-x64.exe',
    [string] $installer = [IO.Path]::Combine($env:TEMP, $url.Substring($url.LastIndexOf('/') + 1)),
    [string] $path = [IO.Path]::Combine([IO.Path]::Combine(('{0}\' -f $env:SystemDrive), 'mozilla-build'), 'hg'),
    [string] $log = [IO.Path]::Combine([IO.Path]::Combine(('{0}\' -f $env:SystemDrive), 'log'), 'hg-install.log')
  )
  (New-Object Net.WebClient).DownloadFile($url, $installer)
  $installArgs = @('/SP-', '/VerySilent', '/SUPPRESSMSGBOXES', ('/DIR={0}' -f $path), ('/LOG={0}' -f $log))
  & $installer $installArgs
}

function Install-BundleClone {
  param (
    [string] $url = 'https://hg.mozilla.org/hgcustom/version-control-tools/raw-file/default/hgext/bundleclone/__init__.py',
    [string] $path = [IO.Path]::Combine([IO.Path]::Combine(('{0}\' -f $env:SystemDrive), 'mozilla-build'), 'hg'),
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
    [string] $path = [IO.Path]::Combine([IO.Path]::Combine([IO.Path]::Combine(('{0}\' -f $env:SystemDrive), 'mozilla-build'), 'hg'), 'bundleclone.py'),
    [string] $domain
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    Set-IniValue -file $hgrc -section 'extensions' -key 'bundleclone' -value $path
    if ($domain.EndsWith("use1.mozilla.com")) {
      Set-IniValue -file $hgrc -section 'bundleclone' -key 'prefers' -value "ec2region=us-east-1, stream=revlogv1"
    }
    elseif ($domain.EndsWith("usw2.mozilla.com")) {
      Set-IniValue -file $hgrc -section 'bundleclone' -key 'prefers' -value "ec2region=us-west-2, stream=revlogv1"
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
    Unset-IniValue -file $hgrc -section 'extensions' -key 'bundleclone'
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Set-IniValue {
  param (
    [string] $file,
    [string] $section,
    [string] $key,
    [string] $value
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    if (Test-Path $hgrc) {
      Write-Log -message ("{0} :: detected ini file at: {1}" -f $($MyInvocation.MyCommand.Name), $file) -severity 'DEBUG'
      $config = Get-IniContent -FilePath $file
      if (-not $config.ContainsKey($section)) {
        $config.Add($section, @{})
        Write-Log -message ("{0} :: created new [{1}] section" -f $($MyInvocation.MyCommand.Name), $section) -severity 'DEBUG'
      } else {
        Write-Log -message ("{0} :: detected existing [{1}] section" -f $($MyInvocation.MyCommand.Name), $section) -severity 'DEBUG'
      }
      if (-not $config[$section].ContainsKey($key)) {
        try {
          $config[$section].Add($key, $value)
          $encoding = (Get-FileEncoding -path $file)
          Out-IniFile -InputObject $config -FilePath $file -Encoding $encoding -Force
          Write-Log -message ("{0} :: set: [{1}]/{2}, to: '{3}', in: {4}." -f $($MyInvocation.MyCommand.Name), $section, $key, $value, $file) -severity 'INFO'
        } catch {
          Write-Log -message ("{0} :: failed to set ini value. {1}" -f $($MyInvocation.MyCommand.Name), $_.Exception) -severity 'ERROR'
        }
      } else {
        Write-Log -message ("{0} :: detected key: {1} with value: '{2}'." -f $($MyInvocation.MyCommand.Name), $key, $config[$section][$key]) -severity 'DEBUG'
        if ($config[$section][$key] -ne $value) {
          try {
            $config[$section].Set_Item($key, $value)
            $encoding = (Get-FileEncoding -path $hgrc)
            Out-IniFile -InputObject $config -FilePath $hgrc -Encoding $encoding -Force
          Write-Log -message ("{0} :: set: [{1}]/{2}, to: '{3}', in: {4}." -f $($MyInvocation.MyCommand.Name), $section, $key, $value, $file) -severity 'INFO'
          } catch {
            Write-Log -message ("{0} :: failed to set ini value. {1}" -f $($MyInvocation.MyCommand.Name), $_.Exception) -severity 'ERROR'
          }
        }
      }
    }
  }
  end {
    Write-Log -message ("{0} :: Function ended" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Unset-IniValue {
  param (
    [string] $file,
    [string] $section,
    [string] $key
  )
  begin {
    Write-Log -message ("{0} :: Function started" -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    if (Test-Path $file) {
      Write-Log -message ("{0} :: detected ini file at: {1}" -f $($MyInvocation.MyCommand.Name), $file) -severity 'DEBUG'
      $config = Get-IniContent $file
      if ($config.ContainsKey($section)) {
        Write-Log -message ("{0} :: detected section: [{1}]." -f $($MyInvocation.MyCommand.Name), $section) -severity 'DEBUG'
        if ($config[$section].ContainsKey($key)) {
          Write-Log -message ("{0} :: detected key: {1}." -f $($MyInvocation.MyCommand.Name), $key) -severity 'DEBUG'
          try {
            $config[$section].Remove($key)
            $encoding = (Get-FileEncoding -path $file)
            Out-IniFile -InputObject $config -FilePath $file -Encoding $encoding -Force
          } catch {
            Write-Log -message ("{0} :: failed to unset ini value. {1}" -f $($MyInvocation.MyCommand.Name), $_.Exception) -severity 'ERROR'
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

function Get-FileEncoding {
  <#
  .SYNOPSIS
  Gets file encoding.
  .DESCRIPTION
  The Get-FileEncoding function determines encoding by looking at Byte Order Mark (BOM).
  Based on port of C# code from http://www.west-wind.com/Weblog/posts/197245.aspx
  .EXAMPLE
  Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'}
  This command gets ps1 files in current directory where encoding is not ASCII
  .EXAMPLE
  Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'} | foreach {(get-content $_.FullName) | set-content $_.FullName -Encoding ASCII}
  Same as previous example but fixes encoding using set-content
  #>
  [CmdletBinding()]
  param (
   [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
   [string] $Path
  )
  [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
  if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf ) {
    return 'UTF8'
  }
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff) {
    return 'Unicode'
  }
  elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff) {
    return 'UTF32'
  }
  elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76) {
    return 'UTF7'
  }
  return 'ASCII'
}
