module.exports = (env) =>
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  _ = env.require 'lodash'

  class AlarmPlugin extends env.plugins.Plugin

    _groups: []

    init: (app, @framework, @config) =>
      env.logger.info("Starting alarm system")

      # create alarm group "delault" from legacy configuration
      if @config.includes?.length > 0
        @config.groups = [
          {'name': 'default', 'includes': _.clone(@config.includes, true)}
        ]
        @config.includes = undefined

      @_groups = _.clone(@config.groups, true)
      for group in @_groups
        group.actuators = []
        group.active = false
        group.alarm = false

      deviceConfigDef = require('./device-config-schema.coffee')

      @framework.deviceManager.registerDeviceClass 'AlarmSwitch',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) ->
          return new AlarmSwitch(config, lastState)

      @framework.deviceManager.registerDeviceClass 'AlarmSystem',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) =>
          device = new AlarmSystem(config, lastState)
          group = @groupFromDeviceId(device.id)
          group.active = lastState?.state?.value or false
          device._group = group
          device.on 'state', (state) =>
            if state is false
              @setAlarm(device, false) # switch off alarm system
            env.logger.info 'alarm system' + if state then ' activated' else ' deactivated'
            group.active = state
          @on 'alarm', (obj) ->
            device._setTrigger(obj)
          return device

      @framework.on 'deviceAdded', (device) =>
        if device instanceof AlarmSystem then return
        group = @groupFromDeviceId(device.id)

        register = (event, expectedValue) =>
          if device.id in group.includes
            env.logger.debug 'registered ' + device.id + " as sensor for alarm system"
            device.on event, (value) =>
              if value is expectedValue
                @setAlarm(device, true)

        if device instanceof AlarmSwitch
          group.actuators.push device
          # AlarmSwitch is the only actuator acting as sensor
          device.on 'state', (state) =>
            @setAlarm(device, state) # AlarmSwitch also switches off the alarm
        else if device instanceof env.devices.PresenceSensor
          register 'presence', true
        else if device instanceof env.devices.ContactSensor
          register 'contact', false
        else if device instanceof env.devices.Actuator
          if device.id in group.includes
            group.actuators.push device
            env.logger.debug device.id + ' registered as actuator for alarm system'

    setAlarm: (triggeringDevice, alarm) =>
      group = @groupFromDeviceId(triggeringDevice.id)
      if group.active
        if group.alarm is alarm then return
        group.alarm = alarm
        if alarm
          env.logger.debug 'device ' + triggeringDevice.id + ' activated the alarm'
          @emit 'alarm', {group: group, trigger: triggeringDevice}
        else
          # when switching alarm to off, set trigger to null
          @emit 'alarm', {group: group, trigger: null}

        for actuator in group.actuators
          if actuator instanceof env.devices.SwitchActuator
            actuator.changeStateTo(alarm)
          else
            env.logger.debug 'unsupported actuator ' + actuator.id

    groupFromDeviceId: (deviceId) =>
      return undefined unless deviceId?
      return _.find @_groups, (item) ->
        return _.indexOf(item.includes, deviceId) >= 0

  class AlarmSwitch extends env.devices.DummySwitch

  class AlarmSystem extends env.devices.DummySwitch
    _trigger: ""
    _group: null

    attributes:
      trigger:
        description: "device that triggered the alarm"
        type: t.string
      state:
        description: "The current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    getTrigger: () -> Promise.resolve(@_trigger)

    _setTrigger: (obj) ->
      return unless obj.group.name == @_group.name
      trigger = obj.trigger?.name
      # use emtpy string because trigger is shown in gui next to switch
      trigger = "" unless trigger
      @_trigger = if trigger then trigger else ""
      @emit 'trigger', trigger

  return new AlarmPlugin()
