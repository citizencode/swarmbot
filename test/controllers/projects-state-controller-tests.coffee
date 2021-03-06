{ createUser, createProject, message } = require '../helpers/test-helper'
{ p, json } = require 'lightsaber'
sinon = require 'sinon'
ProjectsStateController = require '../../src/controllers/projects-state-controller'
User = require '../../src/models/user'
ColuInfo = require '../../src/services/colu-info'
ShowView = require '../../src/views/projects/show-view'

describe 'ProjectsStateController', ->
  msg = null
  input = null
  controller = null
#  spy = null
  currentUser = null

  beforeEach (done)->
    App.robot =
      adapter: {}

    App.pmReply = (msg, textOrAttachments)=>
      reply = textOrAttachments.text or textOrAttachments
      msg.parts.push reply

    createUser
      state: 'projects#show'
    .then (@currentUser)=>
      currentUser = @currentUser
      input = ''
      msg = message(input, {@currentUser})
      controller = new ProjectsStateController(msg)
      done()

  describe '#create', ->
    describe 'when trying to create a project with the same name as an existing project', ->
      it 'keeps the user in the same state and prompts for a new project name', ->
        @currentUser.set('state', 'projects#create')
        .then (@currentUser)=>
          createProject name: "existing project name"
        .then =>
          controller.input = "existing project name"
          controller.create({})
        .then (foo)->
          msg.currentUser.get('state').should.eq 'projects#create'
          json(foo).should.match /That name is already taken, please enter a new name/
          msg.currentUser.get('stateData').should.deep.eq {}

  describe '#show', ->
    describe "when colu is up", ->
      it "shows an error if project doesn't exist", ->
        controller.show()
        .then ->
          msg.parts[0].should.eq 'Couldn\'t find current project with name "some project id"'
          msg.currentUser.get('state').should.eq 'projects#index'

    describe "when colu is down", ->
      beforeEach ->
        ColuInfo::allHolders.restore?()
        sinon.stub(ColuInfo::, "allHolders").throws(new Promise.OperationalError("bang"))
        sinon.spy(ShowView, 'create')

      afterEach ->
        ColuInfo.prototype.allHolders.restore?()
        ShowView.create.restore?()

      it "shows an error if colu is down", ->
        createProject()
        .then (@project)=>
          controller.show()
        .then (response)->
          currentUser.get("state").should.eq "projects#show"
          json(response).should.match /SOME PROJECT ID/
          ShowView.create.should.have.been.called
          ShowView.create.getCall(0).args[0]['coluError'].should.eq 'bang'

  describe '#capTable', =>
    it 'sends a message containing the cap table url', ->
      createProject()
      .then (@project)=>
        controller.capTable()
      .then ->
        msg.parts[0][0]["image_url"].should.match ///https://chart.googleapis.com/chart///

    it "shows an error if project doesn't exist", ->
      controller.capTable()
      .then ->
        msg.parts[0].should.eq 'Couldn\'t find current project with name "some project id"'
        msg.currentUser.get('state').should.eq 'projects#index'
#       spy.should.have.been.calledWith("Couldn't find current project")

  describe '#rewardsList', ->
    it "shows an error if project doesn't exist", ->
      controller.show()
      .then ->
        msg.parts[0].should.eq 'Couldn\'t find current project with name "some project id"'
        msg.currentUser.get('state').should.eq 'projects#index'
#       spy.should.have.been.calledWith("Couldn't find current project")
