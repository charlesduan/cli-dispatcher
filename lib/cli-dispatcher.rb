require 'optparse'
require 'texttools'
require 'reline'
require 'shellwords'

#
# Constructs a program that can operate a number of user-provided commands. To
# use this class, subclass it and define methods of the form:
#
#   def cmd_name(args...)
#
# Then create an instance of the class and call one of the dispatch methods,
# typically:
#
#   [DispatcherSubclass].new.dispatch_argv
#
# To provide help and/or a category for a command, define the methods
#
#   def help_name; [string] end
#   def cat_name;  [string] end
#
# For the help command, the first line should be a short description of the
# command, which will be used in a summary table describing the command. For the
# category, all commands with the same category will be grouped together in the
# help summary display.
#
# This class incorporates optparse, providing the commands setup_options and
# add_options to pass through options specifications.
#
class Dispatcher

  #
  # Reads ARGV and dispatches a command. If no arguments are given, an
  # appropriate warning is issued and the program terminates.
  #
  def dispatch_argv(default_interactive = false)
    @option_parser ||= OptionParser.new
    add_options(@option_parser)
    @option_parser.banner = <<~EOF
      Usage: #{File.basename($0)} [options] command [arguments...]
      Run '#{File.basename($0)} help' for a list of commands.

      Options:
    EOF
    @option_parser.on_tail('-h', '--help', 'Show this help') do
      warn(@option_parser)
      warn("\nCommands:")
      cmd_help
      exit 1
    end

    @option_parser.parse!
    if !ARGV.empty?
      exit dispatch(*ARGV) ? 0 : 1
    elsif default_interactive
      cmd_interactive
    else
      STDERR.puts(@option_parser)
      exit 1
    end
  end

  #
  # Dispatches a single command with given arguments. If the command is not
  # found, then issues a help warning. Returns true or false depending on
  # whether the command executed successfully.
  #
  def dispatch(cmd, *args)
    cmd_sym = "cmd_#{cmd}".to_sym
    begin
      if respond_to?(cmd_sym)
        send(cmd_sym, *args)
        return true
      else
        warn("Unknown command #{cmd_sym}. Run 'help' for a list of commands.")
        return false
      end
    rescue ArgumentError
      if $!.backtrace_locations.first.base_label == cmd_sym.to_s
        warn("#{cmd}: wrong number of arguments.")
        warn("Usage: #{signature_string(cmd)}")
      else
        raise
      end
      return false
    end
  end

  def help_string(cmd, all: true)
    cmd_sym = "help_#{cmd}".to_sym
    return signature_string(cmd) unless respond_to?(cmd_sym)
    if all
      return $0 + " " + signature_string(cmd) + "\n\n" + send(cmd_sym)
    else
      return send(cmd_sym).to_s.split("\n", 2).first
    end
  end

  def signature_string(cmd)
    cmd_sym = "cmd_#{cmd}".to_sym
    raise "No such command" unless respond_to?(cmd_sym)
    return cmd + " " + method(cmd_sym).parameters.map { |type, name|
      case type
      when :req then name.to_s
      when :opt then "[#{name}]"
      when :rest then "*#{name}"
      when :keyreq, :key, :keyrest, :block then nil
      else raise "Unknown parameter type #{type}"
      end
    }.compact.join(" ")
  end

  def help_help
    return <<~EOF
    Displays help on commands.

    Run 'help [command]' for further help on that command.
    EOF
  end

  def cmd_help(cmd = nil, all: true)

    if cmd
      warn("")
      warn(help_string(cmd))
      warn("")
      exit(1)
    end

    warn("Run 'help [command]' for further help on that command.")
    warn("")

    grouped_methods = methods.map { |m|
      s = m.to_s
      s.start_with?("cmd_") ? s.delete_prefix("cmd_") : nil
    }.compact.group_by { |m|
      cat_m = "cat_#{m}".to_sym
      respond_to?(cat_m) ? send(cat_m) : nil
    }
    help_cmds(grouped_methods.delete(nil)) if grouped_methods.include?(nil)

    grouped_methods.sort.each do |cat, cmds|
      warn("\n#{cat}\n\n")
      help_cmds(cmds)
    end
  end

  def help_cmds(cmds)
    cmds.sort.each do |cmd|
      warn(TextTools.line_break(
        help_string(cmd, all: false),
        prefix: " " * 12,
        first_prefix: cmd.ljust(11) + ' ',
      ))
    end
  end

  def help_interactive
    return "Start an interactive shell for entering commands."
  end

  #
  # Runs the dispatcher in interactive mode, in which command lines are read
  # from a prompt.
  #
  def cmd_interactive
    stty_save = `stty -g`.chomp
    loop do
      begin
        buf = Reline.readline(interactive_prompt, true)
        exit unless buf
        args = buf.shellsplit
        next if args.empty?
        exit if args.first == 'exit'
        dispatch(*args)
      rescue Interrupt
        system("stty", stty_save)
        exit
      rescue
        STDERR.puts $!.full_message
      end
    end
  end

  #
  # Returns the string for the interactive prompt. Subclasses can override this
  # method to offer more detailed prompts.
  #
  def interactive_prompt
    return "#{File.basename($0)}> "
  end


  #
  # Adds commands relevant when this dispatcher uses Structured data inputs.
  # This method allows for generating documentation on Structured classes.
  #
  # The calling class should implement a method explain_classes that lists at
  # least one Structured class that can be explained.
  #
  def self.add_structured_commands
    def help_explain
      return <<~EOF
        Displays an explanation of a Structured class.

        This will produce documentation on the elements permitted within the
        class. If no class is given, then a listing of known Structured classes
        is produced.
      EOF
    end

    def cmd_explain(class_name = nil)
      if class_name.nil?
        cache = {}
        puts "The following are Structured classes known to this program. Run"
        puts "the command \"explain [class]\" for documentation on any of them."
        puts
        explain_classes.each do |c|
          list_classes(c, cache)
        end
        return
      end

      c = Object.const_get(class_name)
      if c.is_a?(Class) && c.include?(Structured)
        c.explain
      else
        raise "Invalid class #{class_name}"
      end
    end

    unless defined? explain_classes
      def explain_classes
        return []
      end
    end

    def list_classes(c, cache, level = 0)
      unless c.include?(Structured)
        raise "Cannot list classes of a non-Structured class"
      end
      puts(("  " * level) + c.to_s)
      return if cache.include?(c)
      cache[c] = true
      c.subtypes.each do |sc|
        list_classes(sc, cache, level + 1)
      end
    end

    def help_template
      return <<~EOF
        Produces a template for the given Structured class.
      EOF
    end

    def cmd_template(class_name)
      c = Object.const_get(class_name)
      unless c.is_a?(Class) && c.include?(Structured)
        raise("Invalid class #{class_name}")
      end
      puts c.template
    end
  end


  #
  # Creates an OptionParser object for this Dispatcher. The options for the
  # OptionParser are defined in a block passed to this method. The block
  # receives one argument, which is the OptionParser object being created.
  #
  # The banner and -h/--help options will be added automatically to the created
  # OptionParser object.
  #
  # For a slightly simpler way to set up options for this Dispatcher object, see
  # the add_options method.
  #
  def setup_options
    @option_parser = OptionParser.new do |opts|
      yield(opts)
    end
  end

  #
  # Adds command-line options for this class. By default, this method does
  # nothing. Subclasses may override this method to add options. The method will
  # be automatically invoked during a dispatch_argv call, thereby constructing
  # an OptionParser object to handle the command-line arguments.
  #
  # The argument to this method is an OptionParser object, to which the desired
  # options may be added. The banner and -h/--help options will be added
  # automatically to the OptionParser object.
  #
  def add_options(opts)
  end

end
