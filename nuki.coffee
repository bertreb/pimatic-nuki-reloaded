# The amazing dash-button plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  nukiApi = require 'nuki-bridge-api'
  NukiObject = require 'nuki-bridge-api/lib/nuki'
  commons = require('pimatic-plugin-commons')(env)
  M = env.matcher
  _ = require('lodash')

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

      @framework.ruleManager.addActionProvider(new NukiActionProvider(@framework))

      # auto-discovery
      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-nuki', 'Searching for Nuki Smart Locks.'
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
                'pimatic-nuki',
                "#{deviceConfig.name} (#{deviceConfig.nukiId})",
                deviceConfig
              )
      )


  class NukiDevice extends env.devices.SwitchActuator

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

      env.logger.debug "Start constructor Nuki device"

      @addAttribute('lock',
        description: "Status of the lock"
        type: "string"
        acronym: "status"
      )

      env.logger.debug "Attribute lock added"

      @nuki = new NukiObject @plugin.bridge, @config.nukiId
      @debug = @plugin.debug || false
      @base = commons.base @, @config.class

      env.logger.debug "@nuki created"

      #@_state = laststate?.state?.value ? false
      #@_setState @_state
      if @plugin.bridge.list.isFulfilled
        @_lock = "ready"
      else
        @_lock = "not ready"
      @_setLock @_lock
      #@_lock = laststate?.lock?.value ? "not ready"

      env.logger.debug "Attributes state en lock initialized"

      @nuki.on('action', @stateHandler)

      env.logger.debug "@nuki.on created and constructor finished"

      super()


    stateHandler: (state)=>
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

      switch state
        when nukiApi.lockState.LOCKED
          env.logger.debug "Action LOCKED received for Nuki #{@id}"
          @_setState on
          @_setLock 'locked'
        when nukiApi.lockState.LOCKING
          env.logger.debug "Action LOCKING received for Nuki #{@id}"
          @_setState on
          @_setLock 'locking'
        when nukiApi.lockState.UNLOCKING
          env.logger.debug "Action UNLOCKING received for Nuki #{@id}"
          @_setState off
          @_setLock 'unlocking'
        when nukiApi.lockState.UNLOCKED
          env.logger.debug "Action UNLOCKED received for Nuki #{@id}"
          @_setState off
          @_setLock 'unlocked'
        when nukiApi.lockState.UNLATCH
          env.logger.debug "Action UNLATCH received for Nuki #{@id}"
          @_setState off
          @_setLock 'open'
        when nukiApi.lockState.LOCK_N_GO
          env.logger.debug "Action LOCK_N_GO received for Nuki #{@id}"
          @_setLock 'lock-n-go'
        when nukiApi.lockState.LOCK_N_GO_WITH_UNLATCH
          env.logger.debug "Action LOCK_N_GO_WITH_UNLATCH received for Nuki #{@id}"
          @_setLock 'lock-n-go open'
        else
          env.logger.debug "Unknown Action received for Nuki #{@id}, action nr: " + action

    actionHandler: (action)=>
      ###
      LockAction =
        UNLOCK: 1,
        LOCK: 2,
        UNLATCH: 3,
        LOCK_N_GO: 4,
        LOCK_N_GO_WITH_UNLATCH: 5
      ###

      env.logger.debug "ActionHandler, check @plugin.bridge.list.isFulfilled -> ready"

      unless @plugin.bridge.list?.isFulfilled?
        env.logger.debug "Nuki not ready"
        return

      unless @plugin.bridge.list.isFulfilled
        env.logger.debug "Nuki not ready"
        @_setLock "not ready"
        return

      env.logger.debug "ActionHandler, action received: " + action

      switch action
        when nukiApi.lockAction.LOCK
          @nuki.lockAction(nukiApi.lockState.LOCKED, false) #nowait
          .then (resp)=>
            env.logger.debug "Nuki locked"
            @_setState on
            @_setLock "locked"
          .catch (err) =>
            env.logger.debug "Error locking #{@id}: " + JSON.stringify(err,null,2)
        when nukiApi.lockAction.UNLOCK
          @nuki.lockAction(nukiApi.lockState.UNLOCKED, false) #nowait
          .then (resp)=>
            env.logger.debug "Nuki unlocked"
            @_setState on
            @_setLock "unlocked"
          .catch (err) =>
            env.logger.debug "Error unlocking #{@id}: " + JSON.stringify(err,null,2)
        else
          env.logger.debug "Action '#{action}' not implemented"
      Promise.resolve()

    _requestUpdate: () =>
      @base.cancelUpdate()
      @base.debug "Requesting update"

      @nuki.lockState()
      .then (state) =>
        @base.debug "Lock state is #{state}"
        if typeof state is "string"
          state = parseInt state
        @_setState (state is nukiApi.lockState.LOCKED)
      .catch (error) =>
        @base.error "Error:", error
      .finally () =>
        @base.scheduleUpdate @_requestUpdate, @config.interval * 1000

    changeStateTo: (state) ->
      unless @plugin.bridge.list.isFulfilled
        env.logger.info "Nuki not ready"
        @_setLock "not ready"
        @_setState state
        return Promise.resolve()
      if Boolean state
        @actionHandler(nukiApi.lockAction.UNLOCK)
        .then ()=>
          @_setLock "unlocked"
          @_setState state
          return Promise.resolve()
        .catch (err)=>
          env.logger.debug "Error " + err
          return Promise.reject()
      else
        @actionHandler(nukiApi.lockAction.LOCK)
        .then ()=>
          @_setLock "locked"
          @_setState state
          return Promise.resolve()
        .catch (err)=>
          env.logger.debug "Error " + err
          return Promise.reject()

    getLock: () -> Promise.resolve @_lock

    _setLock: (status) =>
      @_lock = status
      @emit 'lock', status

    execute: (command, options) =>
      return new Promise((resolve,reject) =>

        unless @plugin.bridge.list.isFulfilled
          @_setLock "not ready"
          reject()
          return

        env.logger.debug "Execute command: " + command + ", options: " + JSON.stringify(options,null,2)
        switch command
          when "lock"
            env.logger.debug "Lock Nuki #{@id}"
            @nuki.lockAction(nukiApi.lockState.LOCK, false) #nowait
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
            @nuki.lockAction(nukiApi.lockState.UNLOCK, false) #nowait
            .then (resp)=>
              env.logger.debug "Nuki #{@id} unlocked"
              @_setState off
              @_setLock "unlocked"
              resolve()
            .catch (err) =>
              env.logger.debug "Error unlocking #{@id}: " + JSON.stringify(err,null,2)
              reject()
          when "open"
            env.logger.debug "Open Nuki #{@id}"
            @nuki.unlatch() #nowait
            .then (resp)=>
              env.logger.debug "Nuki #{@id} opened"
              @_setState off
              @_setLock "open"
              resolve()
            .catch (err) =>
              env.logger.debug "Error opening #{@id}: " + JSON.stringify(err,null,2)
              reject()
          when "lock-n-go"
            env.logger.debug "Lock-n-go Nuki #{@id}"
            @nuki.unlatch() #nowait
            .then (resp)=>
              env.logger.debug "Nuki #{@id} lock-n-go"
              @_setState off
              resolve()
            .catch (err) =>
              env.logger.debug "Error lock-n-go #{@id}: " + JSON.stringify(err,null,2)
              reject()
          else
            env.logger.debug "Command not implemented: " + command
            reject()
        resolve()
      )

    destroy: () ->
      #@base.cancelUpdate()
      @nuki.removeListener 'action', @stateHandler
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
            return m.match(' open', (m) =>
              setCommand('open')
              match = m.getFullMatch()
            )
          ),
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
          ),
          ((m) =>
            return m.match(' lock-n-go', (m) =>
              setCommand('lock-n-go')
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