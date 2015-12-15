Configuration ServiceConfig {
  Service FirewallDisable {
    Name = 'WinDefend'
    State = 'Stopped'
    StartupType = 'Disabled'
  }
  Service UpdateDisable {
    Name = 'wuauserv'
    State = 'Stopped'
    StartupType = 'Disabled'
  }
  #Service PuppetDisable {
  #  Name = 'puppet'
  #  State = 'Stopped'
  #  StartupType = 'Disabled'
  #}
}
