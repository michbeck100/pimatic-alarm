module.exports = (env) =>
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  _ = env.require('lodash')

  class AlarmPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      env.logger.info("Starting alarm system ...")

      deviceConfigDef = require('./device-config-schema.coffee')

      @framework.deviceManager.registerDeviceClass 'AlarmSwitch',
        configDef: deviceConfigDef.AlarmSwitch
        createCallback: (config, lastState) ->
          return new AlarmSwitch(config, lastState)

      @framework.deviceManager.registerDeviceClass 'AlarmSystem',
        configDef: deviceConfigDef.AlarmSystem
        createCallback: (config, lastState) =>
          # migrate from legacy configuration
          includes = []
          if @config.includes?.length > 0
            env.logger.debug "found legacy config, will be migrated"
            includes = _.clone(@config.includes)
            # remove legacy config
            delete @config.includes

          # copy config from plugin to alarm system device
          config.includes = includes if config.includes?.length == 0
          alarmSystem = new AlarmSystem(config, lastState, @framework)
          return alarmSystem


  class AlarmSwitch extends env.devices.DummySwitch

  class AlarmSystem extends env.devices.DummySwitch

    _alarm: false
    _actuators: []
    _trigger: ""
    _includes: []

    attributes:
      state:
        description: "The current state of the alarm system"
        type: t.boolean
        labels: ['on', 'off']
      trigger:
        description: "The device that triggered the alarm"
        type: t.string

    constructor: (config, lastState, @framework) ->
      super(config, lastState)
      unless config.includes.length != 0
        env.logger.debug "config contains no devices to include"
        return
      @_includes = config.includes

      @framework.once "after init", =>
        for id in @_includes
          device = @framework.deviceManager.devices[id]
          if device?
            registerSensor = (event, expectedValue) =>
              sensor = device
              sensor.on event, (value) =>
                if value is expectedValue
                  @_setAlarm(true, sensor)
              env.logger.debug "device #{sensor.id} registered as sensor for #{@id}"

            if device instanceof AlarmSwitch
              alarmSwitch = device
              # AlarmSwitch is the only actuator acting as sensor
              alarmSwitch.on 'state', (state) =>
                @_setAlarm(state, alarmSwitch) # AlarmSwitch also switches off the alarm
              env.logger.debug "device #{device.id} registered as alarm switch for #{@id}"
            else if device instanceof env.devices.PresenceSensor
              registerSensor 'presence', true
            else if device instanceof env.devices.ContactSensor
              registerSensor 'contact', false
            else if device instanceof env.devices.Actuator
              @_actuators.push device
              env.logger.debug "device #{device.id} registered as actuator for #{@id}"
          else
            env.logger.warn("device with id #{id} not found")

    _setState: (state) ->
      super(state)
      if state is false
        @_setAlarm(false) # switch off alarm system
      env.logger.info "alarm system \"#{@name}\" #{if state then 'activated' else 'deactivated'}"

    getTrigger: () -> Promise.resolve(@_trigger)

    _setTrigger: (trigger) ->
      if @_trigger is trigger then return
      # use empty string because trigger is shown in gui next to switch
      @_trigger = trigger
      @emit 'trigger', trigger

    _setAlarm: (alarm, triggeringDevice) ->
      if @_state
        if @_alarm is alarm then return
        @_alarm = alarm
        @_setTrigger(if alarm then triggeringDevice.name else "")
        for actuator in @_actuators
          if actuator instanceof env.devices.SwitchActuator
            actuator.changeStateTo(alarm)
          else
            env.logger.debug 'unsupported actuator ' + actuator.id

  return new AlarmPlugin()
