#
# Creates a Structured class that can turn into multiple kinds of Structured
# objects.
#
# To use, include StructuredPolymorphic in a relevant class, and then within the
# class body use ClassMethods#type or ClassMethods#types to specify the
# different types of Structured objects that this class can produce.
#
# When a StructuredPolymorphic object is initialized based on a hash, the hash
# is checked for a key called +type+. (The key can be changed using
# ClassMethods#set_type_key.) The value of that +type+ key is used to determine
# what type of Structured object to create.
#
module StructuredPolymorphic

  #
  # This should never be called because the +new+ method is overridden.
  #
  def initialize(*args, **params)
    raise TypeError, "Abstract StructuredPolymorphic class"
  end

  module ClassMethods

    def reset
      @subclasses = {}
      @class_description = nil
      @type_key = :type
    end

    #
    # Provides a description of this class, for use with the #explain method.
    #
    def set_description(desc)
      @class_description = desc
    end

    #
    # Returns the class's description. The given number can be used to limit the
    # length of the description.
    #
    def description(len = nil)
      desc = @class_description || ''
      if len && desc.length > len
        return desc[0, len] if len <= 5
        return desc[0, len - 3] + '...'
      end
      return desc
    end

    #
    # Sets the hash key in which the polymorphic subtype is identified. By
    # default the key is +:type+.
    #
    def set_type_key(key)
      @type_key = key.to_sym
    end

    #
    # Adds a new subtype to this polymorphic superclass.
    #
    # @param name The textual name for identifying the subclass.
    # @param subclass The Structured Class object to be created.
    #
    def type(name, subclass)
      unless subclass.include?(Structured)
        raise ArgumentError, "#{subclass} is not Structured"
      end
      @subclasses[name.to_sym] = subclass
    end

    #
    # Adds multiple subtypes by repeatedly calling #type for all key-value
    # pairs.
    #
    def types(**params)
      params.each do |name, subclass|
        type(name, subclass)
      end
    end

    #
    # Returns the class corresponding to the given type.
    #
    def type_for(name)
      return @subclasses[name.to_sym]
    end

    #
    # Iterates through all the types.
    #
    def each
      @subclasses.sort.each do |type, c| yield(type, c) end
    end

    #
    # Prints out documentation for this class.
    #
    def explain(io = STDOUT)
      io.puts("Polymorphic Structured Class #{self}:")
      if @class_description
        io.puts("\n" + TextTools.line_break(@class_description, prefix: '  '))
      end
      io.puts
      io.puts "Available subtypes:"
      max_type_len = @subclasses.keys.map(&:to_s).map(&:length).max
      @subclasses.sort.each do |type, c|
        desc = c.description(80 - max_type_len - 5)
        desc = c.name if desc == ''
        io.puts "  #{type.to_s.ljust(max_type_len)}  #{desc}"
      end
    end

    def template(indent: '')
      res = "#{indent}# #{name}\n"
      if @class_description
        res << indent
        res << TextTools.line_break(@class_description, prefix: "#{indent}# ")
        res << "\n"
      end
      res << indent << "type: \n"
      res << indent << "...\n"
      return res
    end

    #
    # Constructs a new object of this StructuredPolymorphic type, by inspecting
    # the hash's type identifier and calling the corresponding class's
    # constructor.
    #
    def new(hash, parent = nil)

      # For subclasses, don't use this overridden new method.
      if self.include?(Structured)
        return super(hash, parent)
      end

      type = hash[@type_key] || hash[@type_key.to_s]
      input_err("no type: #{hash.inspect}") unless type
      type_class = @subclasses[type.to_sym]
      input_err("Unknown #{name} type #{type}") unless type_class

      # Remove the type key when initializing the subclass
      new_hash = hash.dup
      new_hash.delete(@type_key)
      new_hash.delete(@type_key.to_s)
      o = type_class.new(new_hash, parent)

      # Set the type value
      o.instance_variable_set(:@type, type)
      return o
    end

    def inherited(base)
      base.include(Structured)
    end

    def input_err(text)
      raise Structured::InputError, "#{name}: #{text}"
    end
  end


  #
  # Extends ClassMethods to the including class's class methods.
  #
  def self.included(base)
    if base.is_a?(Class)
      base.extend(ClassMethods)
      base.reset
    end
  end


end
