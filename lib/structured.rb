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
  # @param hash The initializing hash for this object.
  # @param parent The parent object to this Structured object.
  #
  def initialize(hash, parent = nil)
    receive_parent(parent) if parent
    self.class.receive_hash(self, hash)
  end

  #
  # Processes the parent object for this Structured class. The parent is
  # automatically given for subsidiary Structured objects, triggering a call to
  # this method.
  #
  # By default, +@parent+ is set to the given object. Classes may override this
  # method to do other things with the parent object (for example, test the
  # parent object type).
  #
  def receive_parent(parent)
    @parent = parent
  end

  #
  # Processes the key object for this Structured class. The key is automatically
  # given when this Structured object is a subsidiary of another, within a
  # key-value hash. It is also automatically given when this Structured object
  # is created while processing a default element.
  #
  # By default, this method sets +@key+ to the given object. Classes may
  # override this method to do other things with the key object.
  #
  def receive_key(key)
    @key = key
  end

  #
  # Processes an undefined element in the initializing hash. By default, this
  # raises an error, but classes may override this method to use the undefined
  # elements.
  #
  # @param element The unknown element name, converted to a symbol.
  #
  # @param val The value associated with the unknown element.
  #
  def receive_any(element, val)
    raise NameError, "Unexpected element for #{self.class}: #{element}"
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
      @default_element = nil
      @class_description = nil
    end

    #
    # Provides a description of this class, for use with the #explain method.
    #
    def set_description(desc)
      @class_description = desc
    end

    #
    # Declares that the class expects an element with the given name and type.
    # See element_data for an explanation of +*args+ and +**params+.
    #
    # @param [Symbol] name The name of the element.
    #
    def element(name, *args, **params)
      @elements[name.to_sym] = element_data(*args, **params)
      #
      # By default, when an element is received, a corresponding instance
      # variable is set. Classes using Structured can override this method after
      # the element declaration to perform other tasks.
      #
      define_method("receive_#{name}".to_sym) do |item|
        instance_variable_set("@#{name}".to_sym, item)
      end
    end

    #
    # Accepts a default element for this class.
    #
    def default_element(*args, **params)
      @default_element = element_data(*args, **params)
    end

    # @param type The expected type of the element value. This may be:
    #
    # * A class.
    # * The value +:boolean+, indicating that a boolean is acceptable.
    # * An array containing a single element being a class, signifying that the
    #   expected type is an array of elements matching that class.
    # * A hash containing a single +Class => Class+ pair, signifying that the
    #   expected type is a hash of key-value pairs matching the indicated
    #   classes.
    #
    def element_data(
      type,
      optional: false, description: nil,
      preproc: nil
    )
      # Check the type argument
      case type
      when Class, :boolean
      when Array
        unless type.count == 1 && type.first.is_a?(Class)
          raise TypeError, "Invalid Array type declaration"
        end
      when Hash
        unless type.count == 1 && type.first.all? { |x| x.is_a?(Class) }
          raise TypeError, "Invalid Hash type declaration"
        end
      else
        raise TypeError, "Invalid type declaration #{type.inspect}"
      end

      if preproc
        raise TypeError, "preproc must be a Proc" unless preproc.is_a?(Proc)
      end

      return {
        :type => type,
        :optional => optional,
        :description => description,
        :preproc => preproc,
      }

    end

    #
    # Given a hash, extracts all the elements from it and updates the object
    # accordingly. obj is the object to update, and hash is the data hash.
    #
    def receive_hash(obj, hash)
      raise "Initializer to #{obj.class} is not a Hash" unless hash.is_a?(Hash)
      @elements.each do |elt, data|
        val = hash[elt] || hash[elt.to_s]
        val = data[:preproc].call(val) if data[:preproc]
        unless val
          next if data[:optional]
          raise(ArgumentError, "#{obj.class} needs key #{elt}")
        end
        obj.send("receive_#{elt}".to_sym, convert_item(val, data[:type], obj))
      end

      # Process unknown elements
      unknown_elts = (hash.keys.map(&:to_sym) - @elements.keys)
      return if unknown_elts.empty?
      unless @default_element
        raise(
          NameError,
          "Unexpected element(s) for #{self}: #{unknown_elts.join(', ')}"
        )
      end
      unknown_elts.each do |elt|
        val = hash[elt] || hash[elt.to_s]
        val = @default_element[:preproc].call(val) if @default_element[:preproc]
        item = convert_item(val, @default_element[:type], obj)
        item.receive_key(elt) if item.is_a?(Structured)
        obj.receive_any(elt, item)
      end
    end

    #
    # Given an expected type and an item, checks that the item matches the
    # expected type, and performs any necessary conversions.
    #
    def convert_item(item, type, parent)
      case type
      when :boolean
        return item if item.is_a?(TrueClass) || item.is_a?(FalseClass)
        raise TypeError, "#{item} is not boolean"

      when Array
        raise TypeError, "#{item} is not Array" unless item.is_a?(Array)
        return item.map { |i| convert_item(i, type.first, parent) }

      when Hash
        raise TypeError, "#{item} is not Hash" unless item.is_a?(Hash)
        return item.map { |k, v|
          conv_key = convert_item(k, type.first.first, parent)
          conv_item = convert_item(v, type.first.last, parent)
          conv_item.receive_key(conv_key) if conv_item.is_a?(Structured)
          [ conv_key, conv_item ]
        }.to_h

      else
        return item if item.is_a?(type)
        if item.is_a?(Hash) && type.include?(Structured)
          return type.new(item, parent)
        end
        raise TypeError, "#{item} is not a #{type}" unless item.is_a?(Hash)
      end
    end

    def line_break(text, len: 80, prefix: '', preserve_lines: false)
      res = ''
      strlen = len - prefix.length
      text = text.gsub("\n", " ") unless preserve_lines
      while text.length > strlen
        if text =~ /\A[^\n]{0,#{strlen}}\s+/
          res << prefix + $&.rstrip + "\n"
          text = $'
        else
          res << prefix + text[0, strlen]
          text = text[strlen..-1]
        end
      end
      res << prefix + text
      return res
    end

    #
    # Prints out documentation for this class.
    #
    def explain(io = STDOUT)
      io.puts("Structured Class #{self}:")
      if @class_description
        io.puts("\n" + line_break(@class_description, prefix: '  '))
      end
      io.puts

      @elements.each do |elt, data|
        io.puts(
          "  #{elt}: #{describe_type(data[:type])}" + \
          "#{data[:optional] ? ' (optional)' : ''}"
        )
        if data[:description]
          io.puts(line_break(data[:description], prefix: '    '))
        end
        io.puts()
      end

      if @default_element
        io.puts(
          "  All other elements: #{describe_type(@default_element[:type])}"
        )
        if @default_element[:description]
          io.puts(line_break(@default_element[:description], prefix: '    '))
        end
        io.puts()
      end

    end

    #
    # Provides a textual description of a type.
    #
    def describe_type(type)
      case type
      when :boolean then 'Boolean'
      when Array then "Array of #{describe_type(type.first)}"
      when Hash
        desc1, desc2 = type.first.map { |x| describe_type(x) }
        "Hash of #{desc1} => #{desc2}"
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
