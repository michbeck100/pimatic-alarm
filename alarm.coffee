module.exports = (env) =>
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  _ = env.require 'lodash'

  class AlarmPlugin extends env.plugins.Plugin

    _groups: []

    init: (app, @framework, @config) =>
      env.logger.info("Starting alarm system")

      @_groups = @config.groups
      for group in @_groups
        group.actuators = []

      deviceConfigDef = require('./device-config-schema.coffee')

      @framework.deviceManager.registerDeviceClass 'AlarmSwitch',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) ->
          return new AlarmSwitch(config, lastState)

      @framework.deviceManager.registerDeviceClass 'AlarmSystem',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) =>
          device = new AlarmSystem(config, lastState)
          group = @groupFromDevice(device)
          group.active = lastState?.state?.value or false
          device.on 'state', (state) =>
            if state is false
              @setAlarm(device, false) # switch off alarm system
            env.logger.info 'alarm system' + if state then ' activated' else ' deactivated'
            group.active = state
          @on 'alarm', (trigger) ->
            device._setTrigger(trigger?.name)
          return device

      @framework.on 'deviceAdded', (device) =>
        if device instanceof AlarmSystem then return
        group = @groupFromDevice(device)

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
      group = @groupFromDevice(triggeringDevice)
      if group.active
        if group.alarm is alarm then return
        group.alarm = alarm
        if alarm
          env.logger.debug 'device ' + triggeringDevice.id + ' activated the alarm'
          @emit 'alarm', triggeringDevice
        else
          # when switching alarm to off, set trigger to null
          @emit 'alarm', null

        for actuator in group.actuators
          if actuator instanceof env.devices.SwitchActuator
            actuator.changeStateTo(alarm)
          else
            env.logger.debug 'unsupported actuator ' + actuator.id

    groupFromDevice: (device) =>
      return _.find @_groups, (item) ->
        return _.indexOf(item.includes, device.id) >= 0

  class AlarmSwitch extends env.devices.DummySwitch

  class AlarmSystem extends env.devices.DummySwitch
    _trigger: ""

    attributes:
      trigger:
        description: "device that triggered the alarm"
        type: t.string
      state:
        description: "The current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    getTrigger: () -> Promise.resolve(@_trigger)

    _setTrigger: (trigger) ->
      # use emtpy string because trigger is shown in gui next to switch
      trigger = "" unless trigger
      @_trigger = if trigger then trigger else ""
      @emit 'trigger', trigger

  return new AlarmPlugin()
