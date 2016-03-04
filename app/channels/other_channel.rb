class OtherChannel < ApplicationCable::Channel
  def subscribed
    puts 'i subscribed'
    data = {
        data: 'some data'
    }
    transmit(data)
  end
end