# SoftwareConfig downloads and installs required software
Configuration SoftwareConfig {
  Chocolatey SublimeText3Install {
    Ensure = 'Present'
    Package = 'sublimetext3'
    Version = '3.0.0.3103'
  }
  Chocolatey SublimeText3PackageControlInstall {
    Ensure = 'Present'
    Package = 'sublimetext3.packagecontrol'
    Version = '2.0.0.20140915'
  }
  Chocolatey VisualStudioCommunity2013Install {
    Ensure = 'Present'
    Package = 'visualstudiocommunity2013'
    Version = '12.0.21005.1'
  }
  Chocolatey WindowsSdkInstall {
    Ensure = 'Present'
    Package = 'windows-sdk-8.1'
    Version = '8.100.26654.0'
  }
  Chocolatey MozillaBuildInstall {
    Ensure = 'Present'
    Package = 'MozillaBuild'
    Version = '2.0.0'
  }
  Chocolatey RustInstall {
    Ensure = 'Present'
    Package = 'rust'
    Version = '1.6.0'
  }
}
