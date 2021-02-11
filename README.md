
[![npm version](https://badge.fury.io/js/pimatic-nuki-reloaded.svg)](https://badge.fury.io/js/pimatic-nuki-reloaded)
![node-current](https://img.shields.io/node/v/pimatic-nuki-reloaded)

# pimatic-nuki-reloaded
Pimatic reloaded plugin for controlling Nuki doorlocks.
This plugin is a reloaded version of the pimatic-nuki plugin from [mwittig](https://github.com/mwittig/pimatic-nuki).

The upgrades are:
- callback for lock events (instead of polling)
- button style lock and unlock in gui
- rules actions for locking and unlocking
- configurable adding of extra info fields

## Plugin Configuration

```
{
  "plugin": "nuki-reloaded",
  "active": true,
  "debug": false,
  "host": "ip address of the bridge",
  "port": <port number of the bridge, default:8881>,
  "callbackPort": <portnumber for callback from the bridge, default: 12321>,
  "token": "token from the bridge"
}
```
## Device Configuration

Use the "Discover Devices" function provided by pimatic to automatically discover and setup NukiDevices.
Per NukiDevice following fixed attributes (device variables) are available:
```
  state: if the lock is LOCKED or UINLOCKED
  lock: the status of the lock
    [UNCALIBRATED, LOCKED, UNLOCKING, UNLOCKED, LOCKING,
    UNLATCHED, UNLOCKED_LOCK_N_GO, UNLATCHING]
  battery: whether the battery is at a crital level (<=20%)
```
You can add extra values/attributes provided by the Bridge.
Under Infos in the device config, you can add the extra information fields.
```
  name: The name for the value used by the Nuki Bridge. Must be exactly the same and is thus case sensitive
  type: The type of the info attribute [string|boolean|number]
  unit: The optional unit of the info attribute
  acronym: The optional acronym of the info attribute
```
The extra info fields will also be available as normal device variables.
To check what extra info your bridge is providing you can use a web browser with the following url:
```
  http://<ip address bridge>:<port number bridge>/list?token=<your token>
```
The response with hold the usable values in the 'lastKnownState' object. This is a formatted example of the response you can get.
The values mode, state, stateName and batteryCritical are already used. If the rest is of interest you can add it.
```
      "lastKnownState": {
            "mode": 2,
            "state": 3,
            "stateName": "unlocked",
            "batteryCritical": false,
            "batteryCharging": false,
            "batteryChargeState": 74,
            "doorsensorState": 2,
            "doorsensorStateName": "door closed",
            "timestamp": "2021-02-10T19:26:35+00:00"
          }
```
## Rules
Locks can be controlled via rules

The action syntax:
```
  nuki <NukiDevice Id> [lock | unlock]
```

---
The minimum node requirement is node 10.x.

The plugin is in development. You could backup Pimatic before you are using this plugin!
