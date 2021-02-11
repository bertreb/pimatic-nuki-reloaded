module.exports = {
  title: "pimatic-nuki-reloaded device config schemas"
  NukiDevice:
    title: "Nuki Smart Lock config"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties: {
      nukiId:
        description: "The 8 digit hexadecimal id of the Nuki Smartlock from which the lock state should be retrieved. Its on the sticker on the back of the Nuki Smart Lock"
        type: "string"
      infos:
        description: "Extra info attributes"
        type: "array"
        items:
          type: "object"
          properties:
            name:
              description: "Extra info attribute name"
              type: "string"
            type:
              description: " The type of the info attribute"
              type: "string"
              enum: ["string","boolean","number"]
            unit:
              description: "The optional unit of the info attribute"
              type: "string"
              required: false
            acronym:
              description: "The optional acronym of the info attribute"
              type: "string"
              required: false
      interval:
        description: "The time interval in seconds (minimum 30) at which battery state shall be read"
        type: "number"
        default: 21600
        minimum: 30
    }
}