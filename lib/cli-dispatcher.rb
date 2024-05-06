require 'optparse'

#
# Constructs a program that can operate a number of user-provided commands. To
# use this class, subclass it and define methods of the form:
#
#   def cmd_name(args...)
#
# Then create an instance of the class and call one of the dispatch methods.
#
# To provide help for a command, define a method:
#
#   def help_name
#
# The first line should be a short description of the command, which will be
# used in a summary table describing the command.
#
# This class incorporates optparse, providing the command setup_options to pass
# through options specifications.
#
class Dispatcher

  #
  # Reads ARGV and dispatches a command. If no arguments are given, an
  # appropriate warning is issued and the program terminates.
  #
  def dispatch_argv
    @option_parser ||= OptionParser.new
    @option_parser.banner = <<~EOF
      Usage: #$0 [options] command [arguments...]
      Run '#$0 help' for a list of commands.

      Options:
    EOF
    @option_parser.on_tail('-h', '--help', 'Show this help') do
      warn(@option_parser)
      warn("\nCommands:")
      cmd_help
      exit 1
    end

    @option_parser.parse!
    if ARGV.empty?
      STDERR.puts(@option_parser)
      exit 1
    end
    dispatch(*ARGV)
  end

  #
  # Dispatches a single command with given arguments. If the command is not
  # found, then issues a help warning.
  #
  def dispatch(cmd, *args)
    cmd_sym = "cmd_#{cmd}".to_sym
    begin
      if respond_to?(cmd_sym)
        send(cmd_sym, *args)
      else
        warn("Usage: #$0 [options] command [arguments...]")
        warn("Run '#$0 help' for a list of commands.")
        exit(1)
      end
    rescue ArgumentError
      if $!.backtrace_locations.first.base_label == cmd_sym.to_s
        warn("#{cmd}: wrong number of arguments")
        warn("Usage: #{signature_string(cmd)}")
        exit(1)
      else
        raise $!
      end
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

    methods.map { |m|
      s = m.to_s
      s.start_with?("cmd_") ? s.delete_prefix("cmd_") : nil
    }.compact.sort.each do |cmd|
      warn("%-10s %s" % [ cmd, help_string(cmd, all: false) ])
    end
  end


  #
  # Receives options, passing them to OptionParser. The options are processed
  # when dispatch_argv is called.
  #
  # The banner and -h/--help options will be added automatically.
  #
  def setup_options
    @option_parser = OptionParser.new do |opts|
      yield(opts)
    end
  end

end
