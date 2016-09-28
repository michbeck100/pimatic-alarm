module.exports = {
  title: "Plugin config options"
  type: "object"
  properties:
    variable:
      description: "name of the variable that the alarm triggering device name is set to"
      type: "string"
      default: "AlarmTrigger"
    includes:
      description: "List of device ids to be included in alarm system"
      type: "array"
      default: []
      items:
        type: "string"
}
