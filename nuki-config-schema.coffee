# #pimatic-denon-avr plugin config options
module.exports = {
  title: "pimatic-nuki plugin config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    host:
      description: "Hostname or IP address of the Nuki Bridge"
      type: "string"
    port:
      description: "Service Port of the Nuki bridge"
      type: "number"
      default: 8080
    token:
      description: "The API token configured via the Nuki App when enabling the API"
      type: "string"
}