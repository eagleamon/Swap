config = require '../swap/config.json'
SerialModem = require '../swap/serialmodem'
Manager = require '../swap/manager'
ps = require '../swap/pubsub'
log4js = require 'log4js'
ss = require 'socketstream'

log4js.setGlobalLogLevel log4js.levels.DEBUG

# events = require 'events'
# class DummySerial extends events.EventEmitter     
#   emitData: =>
#       @emit('data', "D(2323)000000000000")
#       setTimeout(@emitData, 1000)

#   constructor: ->
#       setTimeout (=> 
#           @emit('started')
#           @emitData())
#           , 2000
#       @emitData()

serial = new SerialModem config
# serial = new DummySerial()
swapManager = null

serial.on 'started', () ->
    swapManager = new Manager serial, config
    publisher = new ps.Publisher config
    serial.on 'data', (sp) -> ss.api.publish.all 'swapPacket', sp

    # Just to forward things to web interface and others
    swapManager.on 'swapEvent', (sEvent) -> 
        ss.api.publish.all 'swapEvent', sEvent
        publisher.publish "SwapEvent: #{sEvent.text}"

    swapManager.on 'swapStatus', (status) -> 
        ss.api.publish.all 'swapStatus', status
        #TODO: DRY here...
        unit = status.ep.units[1]
        value = status.rawValue * unit.factor + unit.offset
        publisher.publish "status/#{status.mote.location}/#{status.ep.name}: #{value}"



module.exports.actions = (req, res, ss) ->
    # Get manager configuration
    getConfig: () ->
        res null, config: config

    # Save manager configuration
    saveConfig: (config) ->
        res "err"   

    # Get existing network
    getMotes: () ->
        res null, swapManager.motes

    # Get recognized devices
    getDevices: () ->
        res null, swapManager.repo

    # Save mote modifications
    updateMote: (prop, mote) ->
        if prop is 'location'
            swapManager.motes[mote.address].location = mote.location
            res null, swapManager.motes[mote.address]
            # swapManager.send