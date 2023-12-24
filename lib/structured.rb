#
# Sets up a class to receive an initializing hash and to populate information
# about the class from that hash. The expected hash elements are
# self-documenting and type-checking to facilitate future generation of hash
# elements.
#
# The basic usage is to include the +Structured+ module in a class, which gives
# the class a method ClassMethods#element, used to declare elements expected in
# the initializing hash. Once an element is declared, a few things happen:
#
# * The element is looked for upon initialization
#
# * If found, the element is type-checked and possibly converted to a new object
#
# * A method +convert_[name]+ is defined, taking a single parameter. By default,
#   the method sets an instance variable +@[name]+ with the parameter value.
#   Classes may override this method to provide different initialization
#   actions. (Alternately, classes can accept the default initialization methods
#   and override #initialize for further processing.)
#
# ClassMethods also has class-level methods for producing documentation on the
# expected elements, type checking, and so on.
#
module Structured

  #
  # Initializes the object based on an initialization hash. All methods that
  # include Structured should retain this initialization signature to the extent
  # possible, because downstream Structured objects expect to be initialized
  # this way.
  #
  def initialize(hash)
    self.class.receive_hash(self, hash)
  end

  #
  # Takes a hash and sets up the class variables based on the elements of the
  # hash, compared to elements declared for this class.
  #
  def initialize(hash)
  end

  #
  # Methods extended to a Structured class.
  #
  module ClassMethods

    #
    # Sets up a class to manage elements. This method is called when
    # Structured is included in the class.
    #
    def reset_elements
      @elements = {}
    end

    #
    # Declares that the class expects an element with the given name and type.
    #
    #
    # @param [Symbol] name The name of the element.
    #
    # @param type The expected type of the element value. This may be a class or
    # an array containing a single element being a class. The latter signifies
    # that the expected type is an array of elements matching that class.
    # The value +:boolean+ indicates that a boolean is acceptable.
    #
    def element(name, type, optional: false, description: nil)
      check_type(type)
      @elements[name.to_sym] = {
        :type => type,
        :optional => optional,
        :description => description
      }

      #
      # By default, when an element is received, a corresponding instance
      # variable is set. Classes using Structured can override this method after
      # the element declaration to perform other tasks.
      #
      define_method("receive_#{name}".to_sym) do |item|
        instance_variable_set(
          "@#{name}".to_sym,
          self.class.convert_item(item, type)
        )
      end
    end

    #
    # Checks that a type declaration is permissible. Raises TypeError otherwise.
    #
    def check_type(type)
      return true if type.is_a?(Class)
      return true if type == :boolean
      unless type.is_a?(Array) && type.count == 1 && type[0].is_a?(Class)
        raise TypeError, "Invalid type declaration #{type}" 
      end
      return true
    end


    #
    # Given a hash, extracts all the elements from it and updates the object
    # accordingly. obj is the object to update, and hash is the data hash.
    #
    def receive_hash(obj, hash)
      unknown_keys = hash.keys.map(&:to_sym) - @elements.keys
      unless unknown_keys.empty
        raise(
          NameError,
          "Unknown keys #{unknown_keys.join(", ")} for #{obj.class}"
        )
      end

      @elements.each do |elt, data|
        val = hash[elt] || hash[elt.to_s]
        unless val || data[:optional]
          raise(ArgumentError, "#{obj.class} needs key #{elt}")
        end
        obj.send("receive_#{elt}".to_sym, convert_item(val, data[:type]))
      end
    end

    #
    # Given an expected type and an item, checks that the item matches the
    # expected type, and performs any necessary conversions.
    #
    def convert_item(item, type)
      case type
      when :boolean
        return item if item.is_a?(TrueClass) || item.is_a?(FalseClass)
        raise TypeError, "#{item} is not boolean"
      when Array
        raise TypeError, "#{item} is not Array" unless item.is_a?(Array)
        return item.map { |i| convert_item(i, type.first) }
      when Class
        return item if item.is_a?(type)
        if item.is_a?(Hash) && type.include?(Structured)
          return type.new(item)
        end
        raise TypeError, "#{item} is not a #{type}" unless item.is_a?(Hash)
      end
    end

    #
    # Prints out documentation for this class.
    #
    def explain(io = STDOUT)
      io.puts("Structured Class #{self}:")
      @elements.each do |elt, data|
        io.puts(
          "  #{elt}: #{describe_type(data[:type])}" + \
          "#{data[:optional] ? ' (optional)' : ''}"
        )
        io.puts("  #{data['description']}")
        io.puts("")
      end
    end

    #
    # Provides a textual description of a type.
    #
    def describe_type(type)
      case type
      when :boolean then 'Boolean'
      when Array then "Array of #{describe_type(type.first)}"
      else return type.to_s
      end
    end
  end

  #
  # Includes ClassMethods.
  #
  def self.included(base)
    base.extend(ClassMethods)
    base.reset_elements
  end

end
