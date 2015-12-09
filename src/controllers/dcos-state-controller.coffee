debug = require('debug')('app')
{ log, p, pjson } = require 'lightsaber'
{ map, findWhere, sum, pluck } = require 'lodash'
Promise = require 'bluebird'
swarmbot = require '../models/swarmbot'
ApplicationController = require './application-state-controller'
DCO = require '../models/dco.coffee'
User = require '../models/user'
ProposalCollection = require '../collections/proposal-collection'
DcoCollection = require '../collections/dco-collection'
IndexView = require '../views/dcos/index-view'
CreateView = require '../views/dcos/create-view'
ShowView = require '../views/dcos/show-view'
ListRewardsView = require '../views/dcos/list-rewards-view'
CapTableView = require '../views/dcos/cap-table-view'

class DcosStateController extends ApplicationController
  index: ->
    DcoCollection.all()
    .then (@dcos)=>
      @currentUser.balances()
    .then (@userBalances)=>
      debug @userBalances
      @render new IndexView {@dcos, @currentUser, @userBalances}

  show: ->
    @getDco()
    .then (dco)=> dco.fetch()
    .then (@dco)=>


      @dco.allHolders()
    .then (holders)=>
      @userBalance =
        balance: (findWhere holders, { address: @currentUser.get 'btc_address' })?.amount
        totalCoins: sum pluck holders, 'amount'

      @render new ShowView {@dco, @currentUser, @userBalance}
    .error(@_showError)

  # set DCO
  setDcoTo: (data)->
    @currentUser.setDcoTo(data.id).then =>
      @currentUser.exit()
      @redirect()

  create: (data={})->
    if not @input
      # fall through to render template
    else if not data.name
      data.name = @input
    else if not data.description
      data.description = @input
    else if not data.tasksUrl
      data.tasksUrl = @input
    else #if not data.imageUrl
      promise = @parseImageUrl().then (imageUrl)=>
        if imageUrl then data.imageUrl = imageUrl else data.ignoreImage = true
        @saveDco data
        .then (dco)=> @dco = dco

    ( promise ? Promise.resolve() )
    .error (opError)=> @errorMessage = opError.message
    .then => @currentUser.set 'stateData', data
    .then =>
      if @dco?
        @execute transition: 'showDco', flashMessage: 'Project created!'
      else
        @render new CreateView data, {@errorMessage}

  saveDco: (data)->
    new DCO
      name: data.name
      project_statement: data.description
      imageUrl: data.imageUrl ? ''
      project_owner: @currentUser.key()
      tasksUrl: data.tasksUrl
    .save()
    .then (dco)=>
      dco.issueAsset amount: DCO::INITIAL_PROJECT_COINS
      @currentUser.set 'current_dco', dco.key()

  capTable: ->
    @getDco().then (dco)=>

      # TODO: use dco.allHoldersWithNames() after resolving circular reference.
      dco.allHolders().then (holders)=>
        Promise.map holders, (holder)=>
          User.findBy 'btc_address', holder.address
          .then (user)=>
            holder.name = user.get('slack_username')
            holder
          .catch =>
            holder
      .then (holders)=>
        debug holders
        @render new CapTableView { project: dco, capTable: holders }

  rewardsList: (data)->
    @getDco()
    .then (dco)=>
      @render new ListRewardsView {rewards: dco.rewards()}

module.exports = DcosStateController
