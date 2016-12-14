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
    warn: (stmt) ->
      grunt.log.writeln stmt
    error: (stmt) ->
      grunt.log.writeln stmt
  require: (dep) ->
    require(dep)
env.plugins = require('../node_modules/pimatic/lib/plugins') env
env.devices = require('../node_modules/pimatic/lib/devices') env

describe "alarm", ->
  plugin = null
  alarmSystem = null
  alarmSwitch = null
  dummySwitch = null

  framework = null

  beforeEach ->
    framework = new events.EventEmitter()
    framework.deviceManager = {
      registerDeviceClass: (name, {configDef, createCallback}) ->
        if name is "AlarmSystem"
          alarmSystem =
            createCallback(
              {id: "alarm-system", name: "alarmSystem", includes: ["dummy_id", "test_id"]}, null)
        if name is "AlarmSwitch"
          alarmSwitch = createCallback({id: "alarm-system", name: "alarmSystem"}, null)
    }
    plugin = require('../alarm')(env)
    plugin.init(null, framework, {id: "test_id", name: "test"})
    dummySwitch = new env.devices.DummySwitch({id: "dummy_id", name: "dummy"}, null)
    framework.deviceManager.devices = { "dummy_id": dummySwitch }

  it "switching to on should set active state", ->
    alarmSystem.turnOn()
    assert alarmSystem._state is on

  it "switching to off should disable alarm", ->
    alarmSystem.turnOn()
    called = false
    alarmSystem._setAlarm = (alarm, device) ->
      assert alarm is off
      called = true
    alarmSystem.turnOff()
    assert called
    assert alarmSystem._state is off

  describe "after init event", ->

    it "should add actuators", ->
      framework.emit "after init"
      assert alarmSystem._actuators.length is 1
      assert alarmSystem._actuators[0] is dummySwitch

  describe "alarm switch", ->

    beforeEach ->
      framework.deviceManager.devices = { "test_id": alarmSwitch }
      framework.emit "after init"

    it "should activate alarm when switched on", ->
      called = false
      alarmSystem._setAlarm = (alarm, device) =>
        assert device is alarmSwitch
        assert alarm
        called = true
      alarmSwitch.turnOn()
      assert called

    it "should deactivate alarm when switched off", ->
      alarmSwitch.turnOn()
      called = false
      alarmSystem._setAlarm = (alarm, device) =>
        assert alarm is false
        called = true
      alarmSwitch.turnOff()
      assert called

  describe "contact sensor", ->
    sensor = null

    beforeEach ->
      sensor = new env.devices.DummyContactSensor({id: "test_id", name: "contact"})
      sensor.changeContactTo(on)
      framework.deviceManager.devices = { "test_id": sensor }
      framework.emit "after init"
      alarmSystem.turnOn()

    it "should activate alarm when contact changes", ->
      sensor.changeContactTo(false)
      assert alarmSystem._alarm
      assert alarmSystem._trigger == "contact"

  describe "presence sensor", ->
    sensor = null

    beforeEach ->
      sensor = new env.devices.DummyPresenceSensor({id: "test_id", name: "presence"})
      framework.deviceManager.devices = { "test_id": sensor }
      framework.emit "after init"
      alarmSystem.turnOn()

    it "should activate alarm when contact changes", ->
      sensor.changePresenceTo(on)
      assert alarmSystem._alarm
      assert alarmSystem._trigger == "presence"

  describe "setAlarm", ->

    beforeEach ->
      framework.emit "after init"

    it "should ignore alarm if deactivated", ->
      called = false
      dummySwitch.changeStateTo = (state) =>
        called = true
      framework.emit "after init"
      alarmSystem._state = false
      alarmSystem._setAlarm(true, alarmSwitch)
      assert not called

    it "should change state of actuators if activated", ->
      stateChanged = false
      dummySwitch.changeStateTo = (state) =>
        assert state
        stateChanged = true
      alarmSystem._state = true
      alarmSystem._setAlarm(true, alarmSwitch)
      assert stateChanged

    it "should set trigger to name of alarm trigger", ->
      alarmSystem._state = true
      alarmSystem._setAlarm(true, dummySwitch)
      assert alarmSystem._trigger is dummySwitch.name

    it "should set trigger to empty string if alarm is switched off", ->
      alarmSystem._state = true
      alarmSystem._alarm = true
      alarmSystem._trigger = "test"
      alarmSystem._setAlarm(false, null)
      assert alarmSystem._trigger is ""
