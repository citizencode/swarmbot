{ compact, first } = require 'lodash'
{ log, p, pjson } = require 'lightsaber'
ZorkView = require '../zork-view'
moment = require 'moment'

class ListRewardsView extends ZorkView
  constructor: ({@project, @rewardTypes, @rewards})->

  render: ->
    rewards = @rewards.map (reward)=>
      rewardTypeId = reward.get('rewardTypeId')
      rewardType = @rewardTypes.find (rewardType)-> rewardType.key() is rewardTypeId

      [
        moment(reward.get('name'), moment.ISO_8601).format("MMM Do YYYY")
        "#{App.COIN} #{reward.get('rewardAmount')}"
        "*#{reward.recipientRealName}*"
        rewardType.get('name')
        "_#{reward.get('description')}_"
      ].join("   ")

    """
      *AWARDS FOR #{@project.get('name')}*
      #{rewards.join("\n")}
    """

module.exports = ListRewardsView
