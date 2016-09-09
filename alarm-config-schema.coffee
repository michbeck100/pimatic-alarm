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
}
