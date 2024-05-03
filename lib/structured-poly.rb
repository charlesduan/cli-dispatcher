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
  include Structured

  #
  # This should never be called because the +new+ method is overridden.
  #
  def initialize(*args, **params)
    raise TypeError, "Abstract StructuredPolymorphic class"
  end

  module ClassMethods

    def reset
      @subclasses = {}
      @type_key = :type
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
      if subclass.include?(StructuredPolymorphic)
        raise ArgumentError, "#{subclass} cannot be StructuredPolymorphic"
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
    # Constructs a new object of this StructuredPolymorphic type, by inspecting
    # the hash's type identifier and calling the corresponding class's
    # constructor.
    #
    def new(hash, parent = nil)
      type = hash[@type_key] || hash[@type_key.to_s]
      unless type
        raise ArgumentError, "#{name} input with no type: #{hash.inspect}"
      end
      type_class = @subclasses[type.to_sym]
      unless type_class
        raise ArgumentError, "Unknown #{name} type #{type}"
      end

      # Remove the type key when initializing the subclass
      new_hash = hash.dup
      new_hash.delete(@type_key)
      new_hash.delete(@type_key.to_s)
      o = type_class.new(new_hash, parent)

      # Set the type value
      o.instance_variable_set(:@type, type)
      return o
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
