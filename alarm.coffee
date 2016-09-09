module.exports = (env) =>

  class AlarmPlugin extends env.plugins.Plugin

    _actuators: []

    _active: false

    _includes: []

    init: (app, @framework, @config) =>
      env.logger.info("Starting alarm system")

      @_includes = @config.includes

      deviceConfigDef = require('./device-config-schema.coffee')

      @framework.deviceManager.registerDeviceClass 'AlarmSwitch',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) ->
          return new AlarmSwitch(config, lastState, @framework)

      @framework.deviceManager.registerDeviceClass 'AlarmSystem',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) =>
          @_active = lastState?.state?.value or false
          device = new AlarmSystem(config, lastState)
          device.on 'state', (state) =>
            if state is false
              @alarm(device.id, false) # switch off alarm system
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
                env.logger.info 'device ' + device.id + ' activated the alarm'
                @alarm(device.id, true)
          
        if device instanceof AlarmSwitch
          # AlarmSwitch is the only actuator acting as sensor
          device.on 'state', (state) =>
            @alarm(device.id, state) # AlarmSwitch also switches off the alarm
        else if device instanceof env.devices.PresenceSensor
          register 'presence', true
        else if device instanceof env.devices.ContactSensor
          register 'contact', false
        else if device instanceof env.devices.SwitchActuator
          if device.id in @_includes
            @_actuators.push device
            env.logger.debug device.id + ' registered as actuator for alarm system'

    alarm: (id, state) =>
      if @_active
        for actuator in @_actuators
          actuator.changeStateTo(state)

  class AlarmSwitch extends env.devices.DummySwitch

  class AlarmSystem extends env.devices.DummySwitch

  return new AlarmPlugin()
