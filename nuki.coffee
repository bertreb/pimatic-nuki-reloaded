# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  nukiApi = require 'nuki-bridge-api'
  NukiObject = require 'nuki-bridge-api/lib/nuki'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  _ = require('lodash')
  internalIp = require('internal-ip')

  # ###NukiPlugin class
  class NukiPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @bridge = new nukiApi.Bridge @config.host, @config.port, @config.token

      env.logger.debug "New nukiApi.Bridge created"

      @base = commons.base @, 'Plugin'

      # register devices
      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("NukiDevice",
        configDef: deviceConfigDef.NukiDevice,
        createCallback: (@config, lastState) =>
          new NukiDevice(@config, @, lastState)
      )

      @framework.on "after init", =>
        # Check if the mobile-frontend was loaded and get a instance
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', 'pimatic-nuki-reloaded/ui/nuki.coffee'
          mobileFrontend.registerAssetFile 'css', 'pimatic-nuki-reloaded/ui/nuki.css'
          mobileFrontend.registerAssetFile 'html', 'pimatic-nuki-reloaded/ui/nuki.jade'
          #mobileFrontend.registerAssetFile 'js', 'pimatic-tado-reloaded/ui/vendor/spectrum.js'
          #mobileFrontend.registerAssetFile 'css', 'pimatic-tado-reloaded/ui/vendor/spectrum.css'
          #mobileFrontend.registerAssetFile 'js', 'pimatic-tado-reloaded/ui/vendor/async.js'
        else
          env.logger.warn 'your plugin could not find the mobile-frontend. No gui will be available'

      @framework.ruleManager.addActionProvider(new NukiActionProvider(@framework))

      # auto-discovery
      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-nuki-reloaded', 'Searching for Nuki Smart Locks.'
        @lastId = null
        @bridge.list().then (nukiDevices) =>
          for device in nukiDevices
            do (device) =>
              @lastId = @base.generateDeviceId @framework, "nuki", @lastId

              deviceConfig =
                id: @lastId
                name: device.name
                class: 'NukiDevice'
                nukiId: String device.nukiId

              @framework.deviceManager.discoveredDevice(
                'pimatic-nuki-reloaded',
                "#{deviceConfig.name} (#{deviceConfig.nukiId})",
                deviceConfig
              )
      )


  class NukiDevice extends env.devices.Device

    template: 'nuki'

    actions:
      changeStateTo:
        params:
          state:
            type: "boolean"


    ###
    LockStateV1_2 =
      UNCALIBRATED: 0,
      LOCKED: 1,
      UNLOCKING: 2,
      UNLOCKED: 3,
      LOCKING: 4,
      UNLATCHED: 5,
      UNLOCKED_LOCK_N_GO: 6,
      UNLATCHING: 7,
      MOTOR_BLOCKED: 254,
      UNDEFINED: 255

    LockAction =
      UNLOCK: 1,
      LOCK: 2,
      UNLATCH: 3,
      LOCK_N_GO: 4,
      LOCK_N_GO_WITH_UNLATCH: 5
    ###

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name

      @nukiId = @config.nukiId

      env.logger.debug "Start constructor Nuki device"

      @addAttribute('state',
        description: "State of the lock"
        type: "boolean"
        hidden: true
      )
      @addAttribute('battery',
        description: "Critical status of the battery"
        type: "boolean"
        acronym: "battery"
        labels: ["critical","ok"]
      )
      @addAttribute('batteryLevel',
        description: "Battery level"
        type: "number"
        acronym: "batteryLevel"
        unit: "%"
      )
      @addAttribute('lock',
        description: "Status of the lock"
        type: "string"
        acronym: "status"
      )
      env.logger.debug "Attribute battery and lock added"

      @_state = laststate?.state?.value ? false
      @_battery = laststate?.battery?.value ? false
      @_batteryLevel = laststate?.batteryLevel?.value ? 0
      @_lock = laststate?.lock?.value ? ""
      env.logger.debug "Attributes state en lock initialized"

      #@plugin.framework.variableManager.waitForInit()
      #.then ()=>
      @nuki = new NukiObject @plugin.bridge, @config.nukiId

      env.logger.debug "@nuki created"

      #@nuki.on 'batteryCritical', ()=> @_setBattery false

      internalIp.v4()
      .then (ip)=>
        env.logger.debug "Ip address for callback: " + ip
        return @nuki.addCallback(ip, 12321, true)
      .then (nuki)=>
        nuki.on('action', @stateHandler)
        env.logger.debug "Event handler created"
        nuki.on 'batteryCritical', (battery)=> @_setBattery(battery ? true)
        env.logger.debug "Battery handler added"
        @nuki.getCallbacks().map((cb)=> 
          env.logger.debug "Callbacks: " + cb.url
        )
      .finally ()=>
        env.logger.debug "requesting state of the lock"
        @_requestUpdate()
        env.logger.debug "initialization finished"
      .catch (err)=>
        env.logger.debug "Error initializing " + err

      super()

    getTemplateName: -> "nuki"

    stateHandler: (state, response)=>
      ###
      LockStateV1_2 =
        UNCALIBRATED: 0,
        LOCKED: 1,
        UNLOCKING: 2,
        UNLOCKED: 3,
        LOCKING: 4,
        UNLATCHED: 5,
        UNLOCKED_LOCK_N_GO: 6,
        UNLATCHING: 7,
        MOTOR_BLOCKED: 254,
        UNDEFINED: 255
      ###

      env.logger.debug "StateHandler, state received: " + state
      env.logger.debug "StateHandler, response received: " + JSON.stringify(response,null,2)

      switch state
        when nukiApi.lockState.LOCKED
          env.logger.debug "State LOCKED received for '#{@id}'"
          @_setState on
          @_setLock 'locked'
        when nukiApi.lockState.LOCKING
          env.logger.debug "State LOCKING received for '#{@id}'"
          @_setState on
          @_setLock 'locking'
        when nukiApi.lockState.UNLOCKING
          env.logger.debug "State UNLOCKING received for '#{@id}'"
          @_setState off
          @_setLock 'unlocking'
        when nukiApi.lockState.UNLOCKED
          env.logger.debug "State UNLOCKED received for '#{@id}'"
          @_setState off
          @_setLock 'unlocked'
        when nukiApi.lockState.UNLATCH
          env.logger.debug "State UNLATCH received for '#{@id}'"
          @_setState off
          @_setLock 'open'
        when nukiApi.lockState.LOCK_N_GO
          env.logger.debug "State LOCK_N_GO received for '#{@id}'"
          @_setLock 'lock-n-go'
        when nukiApi.lockState.LOCK_N_GO_WITH_UNLATCH
          env.logger.debug "State LOCK_N_GO_WITH_UNLATCH received for '#{@id}'"
          @_setLock 'lock-n-go open'
        else
          env.logger.debug "Unknown State received for '#{@id}', State nr: " + state

      if response?.batteryCritical?
        @_setBattery response.batteryCritical
      if response?.batteryChargeState?
        @_setBatteryLevel response.batteryChargeState

    actionHandler: (action)=>
      ###
      LockAction =
        UNLOCK: 1,
        LOCK: 2,
        UNLATCH: 3,
        LOCK_N_GO: 4,
        LOCK_N_GO_WITH_UNLATCH: 5
      ###

      ###
      env.logger.debug "ActionHandler, check @plugin.bridge.list.isFulfilled -> ready"

      unless @plugin.bridge.list?.isFulfilled?
        env.logger.debug "Nuki not ready"
        return

      unless @plugin.bridge.list.isFulfilled
        env.logger.debug "Nuki not ready"
        @_setLock "not ready"
        return
      ###

      env.logger.debug "ActionHandler, action received: " + action

      switch action
        when nukiApi.lockAction.LOCK
          @nuki.lockAction(nukiApi.lockAction.LOCK, false) #nowait
          .then (resp)=>
            env.logger.debug "'#{@id}' locked"
            @_setState on
            @_setLock "locked"
          .catch (err) =>
            env.logger.debug "Error locking '#{@id}': " + JSON.stringify(err,null,2)
        when nukiApi.lockAction.UNLOCK
          @nuki.lockAction(nukiApi.lockAction.UNLOCK, false) #nowait
          .then (resp)=>
            env.logger.debug "'#{@id}' unlocked"
            @_setState off
            @_setLock "unlocked"
          .catch (err) =>
            env.logger.debug "Error unlocking '#{@id}': " + JSON.stringify(err,null,2)
        else
          env.logger.debug "Action '#{action}' not implemented"
      Promise.resolve()

    _requestUpdate: () =>
      #@base.cancelUpdate()
      env.logger.debug "Requesting update"

      #@nuki.lockState()
      @plugin.bridge.list()
      .then (list) =>
        env.logger.debug "Update list: #{@nukiId} " + JSON.stringify(list,null,2)
        _nuki = _.find(list,(n)=>Number n.nukiId == Number @nukiId)
        if _nuki?.lastKnownState?
          env.logger.debug "LockState is #{state}"
          _state = _nuki.lastKnownState.state
          if typeof _state is "string"
            _state = parseInt _state
          @stateHandler _state, _nuki.lastKnownState
          #@_setState (state is nukiApi.lockState.LOCKED)
      .catch (error) =>
        env.logger.error "Error:", error
      .finally () =>
        @scheduleUpdate = setTimeout(@_requestUpdate, @config.interval * 1000)


    changeStateTo: (state) ->
      #unless @plugin.bridge.list.isFulfilled
      #  env.logger.info "Nuki not ready"
      #  @_setLock "not ready"
      #  @_setState state
      #  return Promise.resolve()
      if state is @_state then return
      if Boolean state
        @actionHandler(nukiApi.lockAction.LOCK)
        .then ()=>
          @_setLock "locked"
          @_setState state
          return Promise.resolve()
        .catch (err)=>
          env.logger.debug "Error " + err
          return Promise.reject()
      else
        @actionHandler(nukiApi.lockAction.UNLOCK)
        .then ()=>
          @_setLock "unlocked"
          @_setState state
          return Promise.resolve()
        .catch (err)=>
          env.logger.debug "Error " + err
          return Promise.reject()

    getState: () -> Promise.resolve @_state

    _setState: (state) =>
      @_state = state
      @emit 'state', state

    getBattery: () -> Promise.resolve @_battery

    _setBattery: (battery) =>
      @_battery = battery
      @emit 'battery', battery

    getBatteryLevel: () -> Promise.resolve @_batteryLevel

    _setBatteryLevel: (batteryLevel) =>
      @_batteryLevel = batteryLevel
      @emit 'batteryLevel', batteryLevel

    getLock: () -> Promise.resolve @_lock

    _setLock: (status) =>
      @_lock = status
      @emit 'lock', status

    execute: (command, options) =>
      return new Promise((resolve,reject) =>

        #unless @plugin.bridge.list.isFulfilled
        #  @_setLock "not ready"
        #  reject()
        #  return

        env.logger.debug "Execute command: " + command + ", options: " + JSON.stringify(options,null,2)
        switch command
          when "lock"
            env.logger.debug "Lock Nuki #{@id}"
            @nuki.lockAction(nukiApi.lockAction.LOCK, false) #nowait
            .then (resp)=>
              env.logger.debug "Nuki locked"
              @_setState on
              @_setLock "locked"
              resolve()
            .catch (err) =>
              env.logger.debug "Error locking #{@id}: " + JSON.stringify(err,null,2)
              reject()
          when "unlock"
            env.logger.debug "Unlock Nuki #{@id}"
            @nuki.lockAction(nukiApi.lockAction.UNLOCK, false) #nowait
            .then (resp)=>
              env.logger.debug "Nuki #{@id} unlocked"
              @_setState off
              @_setLock "unlocked"
              resolve()
            .catch (err) =>
              env.logger.debug "Error unlocking #{@id}: " + JSON.stringify(err,null,2)
              reject()
          else
            env.logger.debug "Command not implemented: " + command
            reject()
        resolve()
      )

    destroy: () ->
      clearTimeout(@scheduleUpdate)
      #@nuki.removeListener 'action', @stateHandler
      @nuki.getCallbacks().map((cb)=> return cb.remove())

      super()

  class NukiActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>


      nukiDevice = null
      @options = {}

      nukiDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class == "NukiDevice"
      ).value()

      setCommand = (command) =>
        @command = command

      m = M(input, context)
        .match('nuki ')
        .matchDevice(nukiDevices, (m, d) ->
          # Already had a match with another device?
          if nukiDevice? and nukiDevices.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          nukiDevice = d
        )
        .or([
          ((m) =>
            return m.match(' lock', (m) =>
              setCommand('lock')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' unlock', (m) =>
              setCommand('unlock')
              match = m.getFullMatch()
            )
          )
        ])

      match = m.getFullMatch()
      if match? #m.hadMatch()
        env.logger.debug "Rule matched: '", match, "' and passed to Action handler"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NukiActionHandler(@framework, nukiDevice, @command, @options)
        }
      else
        return null


  class NukiActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @nukiDevice, @command, @options) ->

    executeAction: (simulate) =>
      if simulate
        return __("would have Nuki action \"%s\"", "")
      else
        @nukiDevice.execute(@command, @options)
        .then(()=>
          return __("\"%s\" Rule executed", @command)
        ).catch((err)=>
          return __("\"%s\" Rule not executed", "")
        )


  # ###Finally
  # Create a instance of my plugin
  # and return it to the framework.
  return new NukiPlugin