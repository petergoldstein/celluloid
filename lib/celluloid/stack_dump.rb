module Celluloid
  class StackDump

    class TaskState < Struct.new(:task_class, :type, :meta, :status, :backtrace)
    end

    class ActorState
      attr_accessor :name, :id, :cell
      attr_accessor :status, :tasks
      attr_accessor :backtrace
    end

    class CellState < Struct.new(:subject_id, :subject_class)
    end

    class ThreadState < Struct.new(:thread_id, :backtrace)
    end

    attr_accessor :actors, :threads

    def initialize
      @actors  = []
      @threads = []

      snapshot
    end

    def snapshot
      Thread.list.each do |thread|
        if thread.celluloid?
          next unless thread.role == :actor
          @actors << snapshot_actor(thread.actor) if thread.actor
        else
          @threads << snapshot_thread(thread)
        end
      end
    end

    def snapshot_actor(actor)
      state = ActorState.new
      state.id = actor.object_id

      if actor.behavior.is_a?(CellBehaviour)
        state.cell = snapshot_cell(actor.behavior)
      end

      tasks = actor.tasks
      if tasks.empty?
        state.status = :idle
      else
        state.status = :running
        state.tasks = tasks.to_a.map { |t| TaskState.new(t.class, t.type, t.meta, t.status, t.backtrace) }
      end

      state.backtrace = actor.thread.backtrace if actor.thread
      state
    end

    def snapshot_cell(behavior)
      state = CellState.new
      state.subject_id = behavior.cell.subject.object_id
      state.subject_class = behavior.cell.subject.class
      state
    end

    def snapshot_thread(thread)
      ThreadState.new(thread.object_id, thread.backtrace)
    end

    def dump(output = STDERR)
      @actors.each do |actor|
        string = ""
        string << "Celluloid::Actor 0x#{actor.id.to_s(16)}"
        if cell = actor.cell
          string << " Celluloid::Cell 0x#{cell.subject_id.to_s(16)}: #{cell.subject_class}"
        end
        string << " [#{actor.name}]" if actor.name
        string << "\n"

        if actor.status == :idle
          string << "State: Idle (waiting for messages)\n"
          display_backtrace actor.backtrace, string
        else
          string << "State: Running (executing tasks)\n"
          display_backtrace actor.backtrace, string
          string << "Tasks:\n"

          actor.tasks.each_with_index do |task, i|
            string << "  #{i+1}) #{task.task_class}[#{task.type}]: #{task.status}\n"
            string << "      #{task.meta.inspect}\n"
            display_backtrace task.backtrace, string
          end
        end

        output.print string
      end

      @threads.each do |thread|
        string = ""
        string << "Thread 0x#{thread.thread_id.to_s(16)}:\n"
        display_backtrace thread.backtrace, string
        output.print string
      end
    end

    def display_backtrace(backtrace, output)
      if backtrace
        output << "\t" << backtrace.join("\n\t") << "\n\n"
      else
        output << "EMPTY BACKTRACE\n\n"
      end
    end
  end
end
