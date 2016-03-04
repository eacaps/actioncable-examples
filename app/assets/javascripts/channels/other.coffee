App.comments = App.cable.subscriptions.create "OtherChannel",

  connected: ->
# FIXME: While we wait for cable subscriptions to always be finalized before sending messages
    console.log('connected')

  received: (data) ->
    console.log(data)