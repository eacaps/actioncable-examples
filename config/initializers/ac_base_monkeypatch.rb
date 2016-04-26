class ActionCable::Server::Base
  def channel_classes
    puts "#{Thread.current.object_id} - entering channel_classes"
    @channel_classes || @mutex.synchronize do
      @channel_classes ||= begin
        sleep(1)
        puts "#{Thread.current.object_id} - channel_classes at each"
        config.channel_paths.each { |channel_path| require channel_path }
        puts "#{Thread.current.object_id} - channel_classes past each"
        puts "#{Thread.current.object_id} - channel_classes at each_with_object"
        config.channel_class_names.each_with_object({}) { |name, hash| hash[name] = name.constantize }
        puts "#{Thread.current.object_id} - channel_classes past each_with_object"
      end
    end
  end
end