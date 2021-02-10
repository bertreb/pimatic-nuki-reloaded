
[![Npm Version](https://badge.fury.io/js/pimatic-nuki-reloaded.svg)](http://badge.fury.io/js/pimatic-nuki-reloaded)
[![Dependency Status](https://david-dm.org/bertreb/pimatic-nuki-reloaded.svg)](https://david-dm.org/bertreb/pimatic-nuki-reloaded)

# pimatic-nuki-reloaded
Pimatic reloaded plugin for controlling Nuki doorlocks.
This plugin is a reloaded version of the pimatic-nuki plugin from [mwittig](https://github.com/mwittig/pimatic-nuki).

The upgrades are:
- callback for lock events (instead of polling)
- button style lock and unlock in gui
- rules actions for locking and unlocking

## Plugin Configuration

  {
    "plugin": "nuki-reloaded",
    "active": true,
    "debug": false,
    "host": "ip address of the bridge",
    "port": <port number of the bridge, default:8881>,
    "callbackPort": <portnumber for callback from the bridge, default: 12321>,
    "token": "token from the bridge"
  }

## Device Configuration

Use the "Discover Devices" function provided by pimatic to automatically discover and setup NukiDevices.
Per NukiDevice following attributes are available
```
	state: if the lock is LOCKED or UINLOCKED
	lock: the status of the lock [UNCALIBRATED,LOCKED,UNLOCKING,UNLOCKED,LOCKING,UNLATCHED,UNLOCKED_LOCK_N_GO,UNLATCHING]
	battery: whether the battery is at a crital level (<=20%)
	batteryLevel: the batteryy charge level (0-100%)
```

## Rules



