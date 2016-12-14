module.exports = {
  title: "pimatic alarm device config schemas"
  AlarmSystem:
    title: "AlarmSytem config"
    type: "object"
    extensions: ["xLink", "xConfirm", "xOnLabel", "xOffLabel"]
    properties:
      includes:
        description: "List of device ids to be included in alarm system"
        type: "array"
        default: []
        items:
          type: "string"
  AlarmSwitch:
    title: "AlarmSwitch config"
    type: "object"
    extensions: ["xLink", "xConfirm", "xOnLabel", "xOffLabel"]
    properties: {}
}
