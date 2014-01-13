require 'vagabond'

class NotifyMash < BasicObject

  def initialize(*args)
    @notifications = []
    @mash = ::Mash.new(*args)
  end

  def add_notification(&block)
    @notifications << block
  end

  def method_missing(sym, *args)
    start_state = @mash.hash
    result = @mash.send(sym, *args)
    if(start_state != @mash.hash)
      @notifications.each do |notify|
        notify.call(self)
      end
    end
    result
  end

end
