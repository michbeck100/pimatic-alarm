events = require 'events'
grunt = require 'grunt'
assert = require 'assert'
Promise = require 'bluebird'

env =
  logger:
    debug: (stmt) ->
      grunt.log.writeln stmt
    info: (stmt) ->
      grunt.log.writeln stmt
    error: (stmt) ->
      grunt.log.writeln stmt
env.plugins = require('../node_modules/pimatic/lib/plugins') env
env.devices = require('../node_modules/pimatic/lib/devices') env

describe "alarm", ->
  config = {
    id: "test_id"
    name: "test"
    variable: "test"
    includes: ["dummy_id"]
  }

  plugin = null
  alarmSystem = null
  alarmSwitch = null
  dummySwitch = null

  framework = new events.EventEmitter()
  framework.deviceManager = {
    registerDeviceClass: (name, {configDef, createCallback, prepareConfig}) ->
      if name is "AlarmSystem"
        alarmSystem = createCallback(config, null)
      if name is "AlarmSwitch"
        alarmSwitch = createCallback(config, null)
  }
  framework.variableManager = {
    setVariableToValue: (name, value) ->
  }

  beforeEach ->
    plugin = require('../alarm')(env)
    plugin.init(null, framework, config)
    dummySwitch = new env.devices.DummySwitch({id: "dummy_id", name: "dummy"}, null)

  it "switching to on should set active state", ->
    alarmSystem.turnOn()
    assert plugin._active is true

  it "switching to off should disable alarm", ->
    alarmSystem.turnOn()
    called = false
    plugin.setAlarm = (device, alarm) ->
      assert alarm is false
      called = true
    alarmSystem.turnOff()
    assert called
    assert plugin._active is false

  describe "deviceAdded event", ->

    it "should add alarm switch to actuators", ->
      framework.emit "deviceAdded", alarmSwitch
      assert alarmSwitch in plugin._actuators

  describe "switch", ->

    beforeEach ->
      framework.emit "deviceAdded", alarmSwitch

    it "should activate alarm when switched on", ->
      called = false
      plugin.setAlarm = (device, alarm) =>
        assert device is alarmSwitch
        assert alarm
        called = true
      alarmSwitch.turnOn()
      assert called

    it "should deactivate alarm when switched off", ->
      alarmSwitch.turnOn()
      called = false
      plugin.setAlarm = (device, alarm) =>
        assert alarm is false
        called = true
      alarmSwitch.turnOff()
      assert called

  describe "setAlarm", ->
    it "should ignore alarm if deactivated", ->
      called = false
      dummySwitch.changeStateTo = (state) =>
        called = true
      framework.emit "deviceAdded", dummySwitch
      plugin._active = false
      plugin.setAlarm(alarmSwitch, true)
      assert not called

    it "should change state of actuators if activated", ->
      stateChanged = false
      dummySwitch.changeStateTo = (state) =>
        assert state
        stateChanged = true
      framework.emit "deviceAdded", dummySwitch
      plugin._active = true
      plugin.setAlarm(alarmSwitch, true)
      assert stateChanged

    it "should emit alarm event", ->
      emitted = false
      plugin.on "alarm", (device) ->
        assert device is alarmSwitch
        emitted = true
      plugin._active = true
      plugin.setAlarm(alarmSwitch, true)
      assert emitted

    it "should set variable to name of alarm trigger", ->
      called = false
      framework.variableManager.setVariableToValue = (name, value) ->
        env.logger.debug name
        assert name is "test"
        assert value is dummySwitch.name
        called = true
      plugin._active = true
      plugin.setAlarm(dummySwitch, true)
      assert called
