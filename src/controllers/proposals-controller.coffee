{log, p, pjson} = require 'lightsaber'
{ Reputation, Claim } = require 'trust-exchange'
ApplicationController = require './application-controller'
Promise = require 'bluebird'
DCO = require '../models/dco'
swarmbot = require '../models/swarmbot'
Proposal = require '../models/proposal'
User = require '../models/user'
ProposalCollection = require '../collections/proposal-collection'
{ values, assign, map } = require 'lodash'

class ProposalsController extends ApplicationController

  list: (@msg, { @community }) ->
    @getDco().then (dco)=>
      dco.fetch().then (dco) =>
        proposals = new ProposalCollection(dco.snapshot.child('proposals'), parent: dco)
        if proposals.isEmpty()
          return @msg.send "There are no proposals to display in #{dco.get('id')}."

        proposals.sortByReputationScore()
        messages = proposals.map @_proposalMessage
        @msg.send messages.join("\n")

    .error(@_showError)

  listApproved: (@msg, { @community }) ->
    @getDco().then (dco)=>
      dco.fetch().then (dco) =>
        proposals = new ProposalCollection(dco.snapshot.child('proposals'), parent: dco)
        if proposals.isEmpty()
          return @msg.send "There are no approved proposals for #{dco.get('id')}.\nList all proposals and rate your favorites!"

        proposals.filter (proposal) ->
          proposal.ratings().size() > 0 && proposal.ratings().score() > 50

        proposals.sortByReputationScore()
        messages = proposals.map @_proposalMessage
        @msg.send messages.join("\n")

    .error(@_showError)

  show: (@msg, { proposalName, @community }) ->
    @getDco().then (dco) =>
      proposal = new Proposal({id: proposalName}, parent: dco)
      proposal.fetch().then (proposal) =>
        msgs = for k, v of proposal.attributes
          "#{k} : #{v}" unless v instanceof Object
        @msg.send msgs.join("\n")

  award: (@msg, { proposalName, awardee, dcoKey }) ->
    @community = dcoKey
    @getDco()
    .then (dco) -> dco.fetch()
    .then (dco) ->
      user = @currentUser()
      if user.canUpdate(dco)
        User.findBySlackUsername(awardee).then (user)=>
          p "user", user
          awardeeAddress = user.get('btc_address')
          p "address", awardeeAddress

          if awardeeAddress?
            proposal = new Proposal({id: proposalName}, parent: dco)
            #TODO: following line for some reason isn't fetching all attributes (i.e. "amount")
            proposal.fetch().then (proposal)-> proposal.awardTo awardeeAddress

            message = "Awarded proposal to #{awardee}"
            @msg.send message
          else
            @msg.send "#{user.get('slack_username')} must register a BTC address to receive this award."
      else
        # @msg.send "Sorry, you don't have sufficient trust in this community to award this proposal."
        @msg.send "Sorry, you must be the progenitor of this DCO to award proposals."

  create: (@msg, { proposalName, amount, @community }) ->
    @getDco().then (dco) ->
      dco.createProposal({ name: proposalName, amount }).then =>
        @msg.send "Proposal '#{proposalName}' created in community '#{dco.get('id')}'"
      .catch (error) =>
        log "proposal creation error: " + error
        @msg.send "Error creating proposal: #{error.message}"
        # TODO: re-throw to log stacktrace

    .error(@_showError)

  #TODO: possibly incorporate some gatekeeping here (i.e. only members of a DCO can vote on the output)
  rate: (@msg, { @community, proposalName, rating }) ->
    @getDco().then (dco) =>
      user = @currentUser()

      Proposal.find(proposalName, parent: dco).fetch().then (proposal) =>
        unless proposal.exists()
          return @msg.send "Could not find the proposal '#{proposal.get('id')}'. Please verify that it exists."

        claim = Claim.put {
          source: user.get('id')
          target: proposal.get('id')
          value: rating * 0.01  # convert to percentage
        }, {
          firebase: path: "projects/#{dco.get('id')}/proposals/#{proposalName}/ratings"
        }
        claim.then (messages) =>
          replies = for message in messages
            "Rating saved to #{message}"
          p replies.join "\n"
          @msg.send "You rated '#{proposal.get('id')}' #{rating}%"
        .catch (error) =>
          @msg.send "Rating failed: #{error}"
          p "#{error}" # TODO: re-throw exception to show stacktrace
    .error(@_showError)

  _proposalMessage: (proposal) ->
    text = "Proposal #{proposal.get('id')}"
    text += " Reward #{proposal.get('amount')}" if proposal.get('amount')?
    score = proposal.ratings().score()
    text += " Rating: #{score}%" unless isNaN(score)
    text



module.exports = ProposalsController
