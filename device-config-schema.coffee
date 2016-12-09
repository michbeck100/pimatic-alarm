module.exports = {
  title: "pimatic alarm device config schemas"
  AlarmSwitch:
    title: "AlarmSwitch config"
    type: "object"
    extensions: ["xLink", "xConfirm", "xOnLabel", "xOffLabel"]
    properties: {}
  AlarmSystem:
    title: "AlarmSytem config"
    type: "object"
    extensions: ["xLink", "xConfirm", "xOnLabel", "xOffLabel"]
    properties: {}
}
