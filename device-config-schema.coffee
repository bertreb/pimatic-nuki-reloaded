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
      interval:
        description: "The time interval in seconds (minimum 30) at which battery state shall be read"
        type: "number"
        default: 21600
        minimum: 30
    }
}