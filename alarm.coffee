module.exports = (env) =>

  class AlarmPlugin extends env.plugins.Plugin

    _actuators: []

    _active: false
    _alarm: false

    _includes: []

    init: (app, @framework, @config) =>
      env.logger.info("Starting alarm system")

      @_includes = @config.includes

      deviceConfigDef = require('./device-config-schema.coffee')

      @framework.deviceManager.registerDeviceClass 'AlarmSwitch',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) ->
          return new AlarmSwitch(config, lastState)

      @framework.deviceManager.registerDeviceClass 'AlarmSystem',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) =>
          @_active = lastState?.state?.value or false
          device = new AlarmSystem(config, lastState)
          device.on 'state', (state) =>
            if state is false
              @setAlarm(device, false) # switch off alarm system
              env.logger.info 'alarm system deactivated'
            @_active = state
          return device

      @framework.on 'deviceAdded', (device) =>
        if device instanceof AlarmSystem then return

        register = (event, expectedValue) =>
          if device.id in @_includes
            env.logger.debug 'registered ' + device.id + " as sensor for alarm system"
            device.on event, (value) =>
              if value is expectedValue
                @setAlarm(device, true)

        if device instanceof AlarmSwitch
          @_actuators.push device
          # AlarmSwitch is the only actuator acting as sensor
          device.on 'state', (state) =>
            @setAlarm(device, state) # AlarmSwitch also switches off the alarm
        else if device instanceof env.devices.PresenceSensor
          register 'presence', true
        else if device instanceof env.devices.ContactSensor
          register 'contact', false
        else if device instanceof env.devices.Actuator
          if device.id in @_includes
            @_actuators.push device
            env.logger.debug device.id + ' registered as actuator for alarm system'

    setAlarm: (triggeringDevice, alarm) =>
      if @_active
        if @_alarm is alarm then return
        if alarm
          env.logger.info 'device ' + triggeringDevice.id + ' activated the alarm'
          @framework.variableManager.setVariableToValue(@config.variable, triggeringDevice.name)
          @emit 'alarm', triggeringDevice
        @_alarm = alarm

        for actuator in @_actuators
          if actuator instanceof env.devices.SwitchActuator
            actuator.changeStateTo(alarm)
          else
            env.logger.debug 'unsupported actuator ' + actuator.id

  class AlarmSwitch extends env.devices.DummySwitch

  class AlarmSystem extends env.devices.DummySwitch

  return new AlarmPlugin()
