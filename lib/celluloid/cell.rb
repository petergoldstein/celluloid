module Celluloid
  # Don't do Cell-like things outside Cell scope
  class NotCellError < Celluloid::Error; end

  class Cell
    attr_reader :proxy, :subject

    def initialize(options)
      @behavior                   = options[:behavior]
      @subject                    = options[:subject]
      @receiver_block_executions  = options[:receiver_block_executions]
      @proxy_class                = options[:proxy_class] || CellProxy
    end

    def after_spawn(actor_proxy, mailbox)
      @proxy = @proxy_class.new(actor_proxy, mailbox, @subject.class.to_s)
    end

    def invoke(call)
      meth = call.method
      if meth == :__send__
        meth = call.arguments.first
      end
      if @receiver_block_executions && meth
        if @receiver_block_executions.include?(meth.to_sym)
          call.execute_block_on_receiver
        end
      end

      task(:call, :method_name => meth, :dangerous_suspend => meth == :initialize) {
        call.dispatch(@subject)
      }
    end

    def handle_exit_event(event, exit_handler)
      # Run the exit handler if available
      @subject.send(exit_handler, event.actor, event.reason)
    end

    def shutdown
      # FIXME: remove before Celluloid 1.0
      if @subject.respond_to?(:finalize) && @subject.class.finalizer != :finalize
        Logger.warn("DEPRECATION WARNING: #{@subject.class}#finalize is deprecated and will be removed in Celluloid 1.0. " +
          "Define finalizers with '#{@subject.class}.finalizer :callback.'")

        task(:finalizer, :method_name => :finalize, :dangerous_suspend => true) { @subject.finalize }
      end

      finalizer = @subject.class.finalizer
      if finalizer && @subject.respond_to?(finalizer, true)
        task(:finalizer, :method_name => finalizer, :dangerous_suspend => true) { @subject.__send__(finalizer) }
      end
    rescue => ex
      Logger.crash("#{@subject.class}#finalize crashed!", ex)
    end

    def task(task_type, method_name = nil, &block)
      @behavior.task(task_type, method_name, &block)
    end
  end
end
