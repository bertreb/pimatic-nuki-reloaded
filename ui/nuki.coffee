$(document).on 'templateinit', (event) ->

  # define the item class
  class NukiItem extends pimatic.DeviceItem

    constructor: (templData, @device) ->
      super(templData, @device)

      # The value in the input
      #@inputValue = ko.observable()

      # temperatureSetpoint changes -> update input + also update buttons if needed
      #@stateAttr = @getAttribute('state')
      #@inputValue(@stAttr.value())

      #attrValue = @stateAttr.value()
      ###
      @stateAttr.value.subscribe( (value) =>
        @inputValue(value)
        attrValue = value
      )
      ###

      # input changes -> call changeTemperature
      ###
      ko.computed( =>
        textValue = @inputValue()
        if textValue? and attrValue? and parseFloat(attrValue) isnt parseFloat(textValue)
          @changeStateTo(parseFloat(textValue))
      ).extend({ rateLimit: { timeout: 1000, method: "notifyWhenChangesStop" } })
      ###

      #@synced = @getAttribute('state').value

    getItemTemplate: => 'nuki'

    afterRender: (elements) =>
      super(elements)

      # find the buttons
      @lockButton = $(elements).find('[name=lockButton]')
      @unlockButton = $(elements).find('[name=unlockButton]')

      @updateStateButtons()

      @getAttribute('state')?.value.subscribe( => @updateStateButtons() )
      return

    # define the available actions for the template
    stateOff: -> @changeStateTo false
    stateOn: -> @changeStateTo true

    updateStateButtons: =>
      stateAttr = @getAttribute('state')?.value()
      switch stateAttr
        when true
          @lockButton.addClass('ui-btn-active')
          @unlockButton.removeClass('ui-btn-active')
        else
          @lockButton.removeClass('ui-btn-active')
          @unlockButton.addClass('ui-btn-active')
      return

    changeStateTo: (state) ->
      @device.rest.changeStateTo({state}, global: no)
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)


  # register the item-class
  pimatic.templateClasses['nuki'] = NukiItem
