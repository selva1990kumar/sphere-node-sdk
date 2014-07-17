_ = require 'underscore'
_.mixin require('sphere-node-utils')._u
SphereClient = require '../../lib/client'
Config = require('../../config').config

CHANNEL_KEY = 'OrderXmlFileExport'
ROLE_ORDER_EXPORT = 'OrderExport'
ROLE_INVENTORY_SUPPLY = 'InventorySupply'
ROLE_PRIMARY = 'Primary'

uniqueId = (prefix) ->
  _.uniqueId "#{prefix}#{new Date().getTime()}_"

# 'InventorySupply' is provided by default
newChannel = ->
  key: uniqueId 'c'

updateChannel = (version) ->
  version: version
  actions: [
    {action: 'changeName', name: {en: 'A Channel'}}
    {action: 'changeDescription', description: {en: 'This is a Channel'}}
    {action: 'setRoles', roles: [ROLE_INVENTORY_SUPPLY, ROLE_ORDER_EXPORT]}
  ]

describe 'Integration Channels', ->

  channels = []

  beforeEach (done) ->
    @client = new SphereClient
      config: Config
      logConfig:
        levelStream: 'info'
        levelFile: 'error'
    @logger = @client._logger

    @client.channels.save(newChannel())
    .then (result) =>
      expect(result.statusCode).toBe 201
      @channelId = result.body.id
      @logger.info @channel, "New channel created: #{@channelId}"
      done()
    .fail (error) -> done _.prettify(error)

  afterEach (done) ->
    @client.channels.byId(@channelId).fetch()
    .then (result) =>
      @client.channels.byId(@channelId).delete(result.body.version)
    .then (result) =>
      @logger.info "Channel deleted: #{@channelId}"
      expect(result.statusCode).toBe 200
      done()
    .fail (error) -> done _.prettify(error)

  it 'should update a channel', (done) ->
    @client.channels.byId(@channelId).fetch()
    .then (result) =>
      @client.channels.byId(@channelId).update(updateChannel(result.body.version))
    .then (result) ->
      expect(result.statusCode).toBe 200
      expect(result.body.name).toEqual {en: 'A Channel'}
      expect(result.body.description).toEqual {en: 'This is a Channel'}
      expect(result.body.roles).toEqual [ROLE_INVENTORY_SUPPLY, ROLE_ORDER_EXPORT]
      done()
    .fail (error) -> done _.prettify(error)

  it 'should create a new channel with given role and return it', (done) ->
    key = uniqueId "channel"
    @client.channels.ensure(key, ROLE_ORDER_EXPORT)
    .then (result) ->
      expect(result.body).toBeDefined()
      expect(result.body.key).toEqual key
      expect(result.body.roles).toEqual [ROLE_ORDER_EXPORT]
      done()
    .fail (error) -> done _.prettify(error)

  it 'should fetch an existing channel, add given role and return it', (done) ->
    @client.channels.byId(@channelId).fetch()
    .then (result) =>
      @client.channels.ensure(result.body.key, ROLE_ORDER_EXPORT)
    .then (result) =>
      @client.channels.ensure(result.body.key, ROLE_PRIMARY)
    .then (result) ->
      expect(result.body.roles).toEqual [ROLE_INVENTORY_SUPPLY, ROLE_ORDER_EXPORT, ROLE_PRIMARY]
      done()
    .fail (error) -> done _.prettify(error)
  , 10000 # 10sec

  it 'should fail if role value is not supported', (done) ->
    @client.channels.byId(@channelId).fetch()
    .then (result) =>
      @client.channels.ensure(result.body.key, 'undefined-role')
    .then (result) ->
      done 'Role value not supported.'
    .fail (error) ->
      expect(error).toBeDefined
      done()
