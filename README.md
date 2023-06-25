# Command-Line Dispatcher Library

Often you have an executable script that takes a subcommand as the first
argument, possibly with further arguments for the subcommand. This library helps
to create such scripts.

## Usage

To use this, create an executable Ruby script containing a subclass of
Dispatcher. The subclass should define methods `cmd_[name]` where `[name]`
corresponds to each command that the script can perform. The arguments to these
methods correspond to the arguments passed on the command line.

Then, the script should create an instance of the class and call
`dispatch_argv`.

## Example

Here is an example script:

```ruby
#!/usr/bin/env ruby
#
# say.rb
#

require 'cli-dispatcher'

# The subclass of Dispatcher
class Say < Dispatcher

    # Print the current time
    def cmd_time
        puts "The time is #{Time.now}."
    end

    # Print a personalized greeting
    def cmd_hello(name)
        puts "Hello, #{name}!"
    end
end

# Execute the command-line arguments
Say.new.dispatch_argv
```

Now you can execute:
```
> ./say.rb time
The time is 2023-06-25 10:46:21.500423279 -0400.
> ./say.rb hello World
Hello, World!
```


## Help for Commands

A key feature of the Dispatcher class is automatic management of help
information. A subclass defining the method `cmd_[name]` can also define
`help_[name]`, which should return a string of help information.

The first line of the help information should be a one-line summary of the
command, with the remaining text explaining the command and its usage further:
```ruby
    def help_hello
        return "Prints a greeting.\n\nThe argument is the name of a person."
    end
```
Running the subcommand `help` will generate a list of commands with appropriate
help information, and `help [command]` will display the help text for the
command:
```
> ./say.rb help hello
Prints a greeting.

The argument is the name of a person.
```

