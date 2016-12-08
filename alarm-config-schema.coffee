module.exports = {
  title: "Plugin config options"
  type: "object"
  properties:
    includes:
      description: "List of device ids to be included in alarm system"
      type: "array"
      default: []
      items:
        type: "string"
    debug:
      description: "Enable debug output"
      type: "boolean"
      default: false
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
            includes:
              description: "List of device ids to be included in alarm system"
              type: "array"
              default: []
              items:
                type: "string"
}
