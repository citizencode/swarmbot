Promise = require 'bluebird'
{log, p, pjson} = require 'lightsaber'
{ partition, sortByOrder, forEach, map, filter } = require 'lodash'
swarmbot = require '../models/swarmbot'

class FirebaseCollection

  @all: Promise.promisify (cb) ->
    swarmbot.firebase().child(@::model::urlRoot).once 'value', (snapshot) =>
      cb null, new @(snapshot)

  constructor: (modelsOrSnapshot, options={})->
    throw new Error("Collection requires a model.") unless @model?

    @parent = options.parent
    if modelsOrSnapshot instanceof Array
      @models = modelsOrSnapshot
    else
      @snapshot = modelsOrSnapshot
      @models = for key, data of @snapshot.val()
        new @model data,
          parent: @parent,
          snapshot: @snapshot.child(key)

  all: -> @models

  get: (i) -> @models[i]

  # TODO: Fetch this collection's path once, set all the models from the snapshot.child() nodes
  fetch: ->
    Promise.all( @map (model) -> model.fetch() )
    .then => @

  # XXX: Breaks if you edit the @models manually and not the @snapshot. (e.g. @filter())
  # Maybe just use the @models instead of numChildren
  isEmpty: ->
    length = if @snapshot? then @snapshot.numChildren() else @models.length
    (length is 0)

  each: (cb)-> forEach @models, cb

  map: (cb)-> map @models, cb

  # TODO: Should this be destructive / edit in-place, or return a new collection?
  filter: (cb) -> @models = filter @models, cb

  size: -> @models.length

module.exports = FirebaseCollection
