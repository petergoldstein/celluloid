module Celluloid
  OWNER_IVAR = :@celluloid_owner # reference to owning actor

  # Wrap the given subject with an Actor
  class CellBehaviour
    attr_reader :cell

    def initialize(options)
      @cell         = Cell.new(options.merge(:behavior => self))
      @actor        = Actor.new(options.merge(:behavior => self))

      options[:subject].instance_variable_set(OWNER_IVAR, @actor)

      setup(options)

      @actor.start
      @cell.after_spawn(@actor.proxy, @actor.mailbox)
    end

    def setup(options)
      handle(Call) do |message|
        @cell.invoke(message)
      end
      handle(BlockCall) do |message|
        task(:invoke_block) { message.dispatch }
      end
      handle(BlockResponse, Response) do |message|
        message.dispatch
      end
    end

    def proxy
      @cell.proxy
    end

    def handle_exit_event(event, exit_handler)
      @cell.handle_exit_event(event, exit_handler)
    end

    # Run the user-defined finalizer, if one is set
    def shutdown
      @cell.shutdown
    end

    # SUPER

    def actor_proxy
      @actor.proxy
    end

    def handle(*patterns, &block)
      @actor.handle(*patterns, &block)
    end

    def task(task_type, method_name = nil, &block)
      @actor.task(task_type, method_name, &block)
    end
  end
end
