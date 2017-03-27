# coding: utf-8
module Fluent
  class ESJvmInput < Fluent::Input
    Fluent::Plugin.register_input('esjvm', self)

    config_param :tag,        :string,  default: 'esjvm'
    config_param :interval,   :integer, default: 60
    config_param :host,       :string,  default: 'http://127.0.0.1:9200'

    def initialize
      super
      require 'net/http'
      require 'uri'
      require 'json'
    end

    def configure(conf)
      super
    end

    def start
      @loop = Coolio::Loop.new
      @tw = TimerWatcher.new(interval, true, log, &method(:execute))
      @tw.attach(@loop)
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @tw.detach
      @loop.stop
      @thread.join
    end

    def run
      @loop.run
    rescue => e
      log.error 'unexpected error', error: e.to_s
      log.error_backtrace
    end

    private

    def execute
      @time = Engine.now
      record = _get_record
      log.debug(record)
      Engine.emit(@tag, @time, record)
    rescue => e
      log.error('faild to run', error: e.to_s, error_class: e.class.to_s)
      log.error_backtrace
    end

    def _get_record
      record = Hash.new(0)
      uri = URI.parse("#{@host}/_nodes/stats/jvm,process")
      log.debug(uri)

      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request) do |response|
          result = JSON.parse(response.body) rescue next
          log.debug(response.body)
        
          nodeid    = result['nodes'].keys
          node_mum  = result['nodes'].keys.size
          node_mum  = node_mum -1

          record = Hash.new(0)

          for i in 0..node_mum do
              node_name = result['nodes'][nodeid[i]]['name']
              record.store(node_name + "_open_file", result['nodes'][nodeid[i]]['process']['open_file_descriptors'])
              record.store(node_name + "_max_file", result['nodes'][nodeid[i]]['process']['max_file_descriptors'])
              record.store(node_name + "_heap_used", result['nodes'][nodeid[i]]['jvm']['mem']['heap_used_in_bytes'])
              record.store(node_name + "_heap_committed", result['nodes'][nodeid[i]]['jvm']['mem']['heap_committed_in_bytes'])
              record.store(node_name + "_heap_max", result['nodes'][nodeid[i]]['jvm']['mem']['heap_max_in_bytes'])
              record.store(node_name + "_heap_used", result['nodes'][nodeid[i]]['jvm']['mem']['heap_used_in_bytes'])
          end
          log.debug(response.body)

        end
      end
      record
    end

    class TimerWatcher < Coolio::TimerWatcher
      def initialize(interval, repeat, log, &callback)
        log = log
        @callback = callback
        super(interval, repeat)
      end

      def on_timer
        @callback.call
      rescue => e
        log.error e.to_s
        log.error_backtrace
      end
    end
  end
end