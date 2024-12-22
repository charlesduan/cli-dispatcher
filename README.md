# Command-Line Dispatcher Library

Often you have an executable script that takes a subcommand as the first
argument, possibly with further arguments for the subcommand. This library helps
to create such scripts.

Additionally, this gem includes two support packages that are useful in
conjunction with a command-line dispatcher: an class for structured input from
YAML or other files, and text processing helpers.

## Usage

To use this, create an executable Ruby script containing a subclass of
Dispatcher. The subclass should define methods `cmd_[name]` where `[name]`
corresponds to each subcommand that the script can perform. The arguments to
these methods correspond to the arguments passed on the command line.

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
subcommand, with the remaining text explaining the command and its usage
further:
```ruby
    def help_hello
        return "Prints a greeting.\n\nThe argument is the name of a person."
    end
```
Running the subcommand `help` will generate a list of subcommands with
appropriate help information, and `help [command]` will display the help text
for the subcommand:
```
> ./say.rb help hello
Prints a greeting.

The argument is the name of a person.
```

**Categorizing commands:** When a dispatcher has many subcommands, it may become
difficult to navigate all the subcommands in the help listing. To alleviate
this, subcommands may be associated with a category by defining a method
`cat_[name]`, returning a string indicating the category:
```ruby
    def cat_hello
        return "Text Commands"
    end
```
The listing of subcommands will now organize the descriptions under categories:
```
> ./say help

... [Other command help]

Text Commands

hello     Prints a greeting.
```

# Structured Input from YAML Files

Command-line scripts often receive input from data files, often formatted as
YAML or JSON. These file formats generally only support simple data types such
as arrays and hashes. Often it is convenient to convert these into Ruby objects.
But because the input files are composed of those simpler types, keeping track
of and documenting the required elements for the input files can be difficult.

## Problems with the Basic Approach

Consider, for example, a program that involves Book objects. A Book in this
program has a title, a subtitle, a list of authors, and an array of Chapter
objects. Each chapter has a title and a starting page number. A YAML file
describing one such Book object might look like this:

```yaml
---
title: The Mythical Man-Month
subtitle: Essays on Software Engineering
authors:
  - Frederick P. Brooks
chapters:
  - page: 3
    name: The Tar Pit
  - page: 13
    name: The Mythical Man-Month
...
```

The corresponding Ruby classes might read:
```ruby
class Book
    attr_accessor :title, :subtitle, :authors, :chapters
    def initialize(hash)
        @title, @subtitle = hash['title'], hash['subtitle']
        @authors = hash['authors']
        @chapters = hash['chapters'].map { |ch| Chapter.new(ch) }
    end
end
class Chapter
    attr_accessor :name, :page
    def initialize(hash)
        @name, @page = hash['name'], hash['page']
    end
end
```

This basic approach suffers from a number of flaws:

- There is no easy way, other than reading the Ruby source code, to know what
  fields or values to include in the YAML file.

- Any documentation of the required YAML elements will be written separately
  from the operating code, allowing them to drift out of sync over time.

- There is no type checking for the input values.

- There is no checking for missing or spurious input elements. A typo or
  misnaming of an element key (say, `name` rather than `title`) may raise no
  obvious error.

- There is no automatic two-way association between a Book and a Chapter.

- If there is an error in the contents of the input file (say, a missing chapter
  title), it may be difficult to determine which item in the input file led to
  the error.

- The object's initialization code is repetitive and error-prone: instance
  variables and accessors have to be created, and initial values need to be
  drawn out of the hash. Solving the above problems for each element only adds
  to the amount of repetitive code.

- It sure would be nice to be able to generate a template YAML file when
  writing new input files.



## The Structured Module

The Structured module provided in this gem offers an improved way of converting
from YAML or other basic input files to Ruby objects. To use it, a class
includes Structured and then calls the `element` method:

```ruby
class Chapter
    include Structured
    set_description("Metadata about one chapter in a book")
    element(:name, String, description: "Chapter name")
    element(:page, Integer, description: "Starting page of the chapter")
end
class Book
    include Structured
    set_description("Metadata about a book")
    element(:title, String, description: "Title of the book")
    element(:subtitle, String, description: "Subtitle of the book")
    element(:authors, [ String ], description: "List of authors")
    element(:chapters, [ Chapter ], description: "List of chapters in the book")
end
```

(Note that Chapter must now be defined before Book, because the element command
needs to dereference the Chapter class type.)

These Structured classes automatically provide type checking and verification of
elements in the input file, based on the given types. Hierarchical parent
relationships among Structured objects are automatically set.

Additionally, a Structured class can produce documentation and template files
for users. The Dispatcher class above can automatically add user-level commands
for producing these.

Finally, a Structured class allows for separating a YAML file into multiple
sub-files, as described further in the documentation.


# Text Tools

Because command-line interfaces often generate text outputs, the TextTools
module offers methods for line breaking, inserting commas into lists, primitive
markdown conversion, and number formatting.

