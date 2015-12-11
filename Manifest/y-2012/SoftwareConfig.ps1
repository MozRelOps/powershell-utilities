# SoftwareConfig downloads and installs required software
Configuration SoftwareConfig {
  Chocolatey SublimeText3Install {
    Ensure = 'Present'
    Package = 'sublimetext3'
    Version = '3.0.0.3083'
  }
  Chocolatey SublimeText3PackageControlInstall {
    Ensure = 'Present'
    Package = 'sublimetext3.packagecontrol'
    Version = '2.0.0.20140915'
  }
}
