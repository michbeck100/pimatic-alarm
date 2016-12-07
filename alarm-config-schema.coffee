module.exports = {
  title: "Plugin config options"
  type: "object"
  properties:
    groups:
      description: "List of alarm device groups"
      type: "array"
      default: []
      items:
        description: "Alarm group"
        type: "object"
        properties:
          name:
            description: "Name of the group"
            type: "string"
          active:
            description: "Alarm group enabled"
            type: "boolean"
            default: false
          alarm:
            description: "Alarm group enabled"
            type: "boolean"
            default: false
          includes:
            description: "List of device ids to be included in alarm system"
            type: "array"
            default: []
            items:
              type: "string"
          actuators:
            description: "List of device ids to be included in alarm system"
            type: "array"
            default: []
            items:
              type: "string"
}
