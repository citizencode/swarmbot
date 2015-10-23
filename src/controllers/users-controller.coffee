{ p, pjson } = require 'lightsaber'
{ address } = require 'bitcoinjs-lib'
ApplicationController = require './application-controller'
swarmbot = require '../models/swarmbot'
User = require '../models/user'
DCO = require '../models/dco'

class UsersController extends ApplicationController
  register: (@msg) ->
    # p "currentUser", @currentUser()
    @currentUser().fetch().then (user) =>

      slackUsername = @msg.message.user.name
      slackId = @msg.message.user.id
      realName = @msg.message.user.real_name
      emailAddress = @msg.message.user.email_address
      # p user, slackId, realName, emailAddress

      # quickfix, set to silent register, now that it is automated

      if slackUsername && !user.get('slack_username')
        user.set "account_created", Date.now()
        user.set "slack_username", slackUsername

      if slackUsername
        user.set "last_active_on_slack", Date.now()


      if process.env.HUBOT_DEFAULT_COMMUNITY && !user.get('current_dco')
        user.set "current_dco", process.env.HUBOT_DEFAULT_COMMUNITY
        # @msg.send "registered Slack username"

      if realName
        user.set "real_name", realName
        # @msg.send "registered real name"

      if emailAddress
        user.set "email_address", emailAddress
        # @msg.send "registered email address"

      if slackId
        user.set "slack_id", slackId
        # @msg.send "registered slack id"

  registerBtc: (@msg, { btcAddress }) ->
    try
      address.fromBase58Check(btcAddress)
    catch error
      p error.message
      return @msg.send "'#{btcAddress}' is an invalid bitcoin address.  #{error.message}"

    user = @currentUser()
    user.set "btc_address", btcAddress
    @msg.send "BTC address #{btcAddress} registered."

  setCommunity: (@msg, { community }) ->
    user = @currentUser()
    user.setDco community
    @msg.send "Your current community is now '#{community}'."

  unsetCommunity: (@msg) ->
    user = @currentUser()
    user.setDco null
    @msg.send "Your current community has been unset."

  getInfo: (@msg, { slackUsername }) ->
    userPromise = if slackUsername == 'me'
      @currentUser().fetch()
    else
      User.findBySlackUsername(slackUsername)

    userPromise.then (user) =>
      info = @_userText(user)
      @msg.send info
    .error (error)=>
      @msg.send error

module.exports = UsersController
