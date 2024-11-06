require_relative 'texttools'

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
# * If found, the element's value is type-checked and possibly converted to a
#   new object. In particular:
#
#   * If the expected type is a Structured object, then the value is expected to
#     be a hash, which is used as input to construct the expected Structured
#     object. This subsidiary Structured object has its +@parent+ instance
#     variable set so that a complete two-way tree of objects is maintained.
#
#   * If the expected type is an Array of Structured objects, then the value is
#     expected to be an array of hashes, each of which is converted to the
#     expected Structured object. The +@parent+ variable is also set.
#
#   * If the expected type is a Hash including Structured object, then the value
#     is similarly converted to a hash of Structured objects. As an added
#     benefit, besides +@parent+ being set, hash values have the +@key+ instance
#     variable set, so that the values are aware of the hash key with which they
#     are associated.
#
# * An instance variable +@[element]+ is set to the given value.
#
# As a result, at the end of the initialization of a Structured object, it will
# have instance variables set corresponding to all the defined elements.
#
# The above explanation is default behavior, and several customizations are
# available.
#
# * Methods +receive_[element]+ can be defined, taking a single parameter. By
#   default, the method sets an instance variable +@[name]+ with the parameter
#   value. Classes may override this method to provide different initialization
#   actions. (Alternately, classes can accept the default initialization methods
#   and override #initialize for further processing.)
#
# * Methods receive_parent and receive_key can be similarly redefined to change
#   the processing of parent Structured objects and hash keys, respectively.
#
# * To process unknown elements, call ClassMethods#default_element to specify
#   their expected type. (It should typically be just a class name, as that
#   method's documentation explains.) Then define +receive_any+ to handle
#   undefined elements, for example by placing them in a hash. For these
#   elements, the +@key+ instance variable is also set for them if the expected
#   type is a Structured class.
#
# Please read the documentation for Structured::ClassMethods for more on
# defining expected elements, type checking, and so on.
#
module Structured

  #
  # Error class when there is a defect in Structured input. This class will
  # eventually provide more robust tracing information about where the error
  # occurred.
  #
  class InputError < StandardError
    attr_accessor :structured_stack

    def to_s

      res = [ [ nil, nil ] ]

      @structured_stack.each do |item|
        if item.is_a?(Class)
          res.last[0] = item
        else
          res.push([ nil, nil ])
          res.last[1] = item
        end
      end

      return res.map { |cls, item|
        case
        when item && cls then "\"#{item}\" (#{cls})"
        when item then "\"#{item}\""
        when cls then "#{cls}"
        else nil
        end
      }.compact.join(" -> ") + ": " + super
    end

    def backtrace
      return []
    end

    def cause
      return nil
    end

  end


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
    Structured.trace(self.class) do
      pre_initialize
      receive_parent(parent) if parent
      self.class.receive_hash(self, hash)
    end
  end

  #
  # Subclasses may override this method to provide pre-initialization routines.
  #
  def pre_initialize
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
  # Methods extended to a Structured class. A class would typically use the
  # following methods within its class body:
  #
  # * #set_description to set a textual description of the object
  #
  # * #element to define expected elements of the input hash
  #
  # * #default_element to define processing of unknown element keys
  #
  # The #explain method is also useful for printing out documentation for a
  # Structured class.
  #
  module ClassMethods

    #
    # Sets up a class to manage elements. This method is called when
    # Structured is included in the class.
    #
    # As an implementation note: Information about a Structured class is stored
    # in instance variables of the class's object.
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
    # Declares that the class expects an element with the given name and type.
    # See element_data for an explanation of +*args+ and +**params+.
    #
    # @param [Symbol] name The name of the element.
    # @param attr Whether to create an attribute (i.e., call +attr_reader+) for
    # the given element. Default is true.
    #
    def element(name, *args, attr: true, **params)
      @elements[name.to_sym] = element_data(*args, **params)
      #
      # By default, when an element is received, a corresponding instance
      # variable is set. Classes using Structured can define +receive_[name]+ so
      # that the element declaration will perform other tasks.
      #
      # This creates the reader attribute only if there is no other method of
      # the same name.
      #
      attr_reader(name) if attr && !method_defined?(name)
    end

    #
    # Removes an element. Note that the attribute definition if any and the
    # +receive_[name]+ method are left intact.
    #
    def remove_element(name)
      @elements.delete(name.to_sym)
    end

    #
    # Accepts a default element for this class. The arguments are the same as
    # those for element_data.
    #
    # **Caution**: The type argument should almost always be a single class, and
    # not a hash. This is because the default arguments are automatically
    # treated like a hash, with the otherwise-undefined element names being the
    # keys of the hash.
    #
    def default_element(*args, **params)
      @default_element = element_data(*args, **params)
    end

    #
    # Processes the definition of an element.
    #
    # @param type The expected type of the element value. This may be:
    #
    # * A class.
    #
    # * The value +:boolean+, indicating that a boolean is acceptable.
    #
    # * An array containing a single element being a class, signifying that the
    #   expected type is an array of elements matching that class.
    #
    # * A hash containing a single +Class1 => Class2+ pair, signifying that the
    #   expected type is a hash of key-value pairs matching the indicated
    #   classes. If Class2 is a Structured class, then Class2 objects will have
    #   their Structured#receive_key method called, with the corresponding
    #   Class1 object as the argument.
    #
    # @param optional Whether the element is optional. Set to :omit to omit it
    #   from templates.
    #
    # @param description A text description of the element.
    #
    # @param preproc A Proc that will be executed on the element value to
    # convert it. The proc will be executed in the context of the receiving
    # object.
    #
    # @param default A default value, entered into templates. The default value
    # is also used for optional elements that are not specified in an input
    # hash.
    #
    # @param check A mechanism for checking for the validity of an element
    # value. This may be:
    #
    # * A Proc, in which case it should return true for valid values.
    # * An Array of valid values (tested by +===+}).
    # * Any other object, in which case validity is determined by whether the
    #   check value +===+ the element value.
    #
    def element_data(
      type,
      optional: false, description: nil,
      preproc: nil, default: nil, check: nil
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

      case check
      when nil, Proc then check_obj = check # Pass through
      when Array then check_obj = proc { |o| check.any? { |c| c === o } }
      else check_obj = proc { |o| check === o }
      end

      return {
        :type => type,
        :optional => optional,
        :description => description,
        :preproc => preproc,
        :default => default,
        :check => check_obj,
      }

    end

    #
    # Iterates elements in a useful sorted order.
    #
    def each_element
      @elements.sort_by { |e, data|
        if data[:optional] == :omit
          [ 3, e.to_s ]
        else
          [ data[:optional] ? 2 : 1, e.to_s ]
        end
      }.each do |e, data|
        yield(e, data)
      end
    end

    #
    # Given a hash, extracts all the elements from it and updates the object
    # accordingly. This method is called automatically upon initialization of
    # the Structured class.
    #
    # @param obj the object to update
    # @param hash the data hash.
    #
    def receive_hash(obj, hash)
      input_err("Initializer is not a Hash") unless hash.is_a?(Hash)

      @elements.each do |elt, data|
        Structured.trace(elt.to_s) do
          val = hash[elt] || hash[elt.to_s]
          next if process_nil_val(obj, elt, val, data)

          if data[:preproc]
            val = try_run(data[:preproc], obj, val, "preproc")
            next if process_nil_val(obj, elt, val, data)
          end

          cval = convert_item(val, data[:type], obj)

          # Check for validity after preproc and conversion are run
          if data[:check] && !try_run(data[:check], obj, cval, "check")
            input_err "Value #{cval} failed check for #{elt}"
          end

          # Use the converted value
          apply_val(obj, elt, cval)
        end
      end

      # Process unknown elements
      unknown_elts = (hash.keys.map(&:to_sym) - @elements.keys)
      return if unknown_elts.empty?
      unless @default_element
        input_err("Unexpected element(s): #{unknown_elts.join(', ')}")
      end
      unknown_elts.each do |elt|
        Structured.trace(elt.to_s) do
          de = @default_element
          val = hash[elt] || hash[elt.to_s]
          if de[:preproc]
            val = try_run(de[:preproc], obj, val, "default preproc")
          end
          item = convert_item(val, de[:type], obj)
          if de[:check] && !try_run(de[:check], obj, item, "check")
            input_err "Value #{item} failed default element check"
          end
          item.receive_key(elt) if item.is_a?(Structured)
          obj.receive_any(elt, item)
        end
      end
    end

    # Deals with a nil value (either because no value was given, or because a
    # preproc deleted it).
    #
    # * If val is non-nil, then this method returns false.
    # * If val is nil and this element is non-optional, then this method raises
    #   an error.
    # * If val is nil and the element is optional, *and* the element has a
    #   default value, then the object has the default value applied to the
    #   element.
    # * In any event, if val is nil and the element is optional, returns true
    #   which should signal to the caller to stop further processing of the
    #   element.
    #
    def process_nil_val(obj, elt, val, data)
      return false if val
      input_err("Missing (or preproc deleted) #{elt}") unless data[:optional]
      apply_val(obj, elt, data[:default]) if data[:default]
      return true
    end

    # Applies a value to an element for an object, after all processing for the
    # value is done.
    def apply_val(obj, elt, val)
      if obj.respond_to?("receive_#{elt}")
        obj.send("receive_#{elt}".to_sym, val)
      else
        obj.instance_variable_set("@#{elt}", val)
      end
    end

    def try_run(block, obj, val, err_name)
      begin
        val = obj.instance_exec(val, &block)
      rescue StandardError => e
        input_err("#{err_name} failed: #{e.to_s}")
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
        input_err("#{item} is not boolean")

      when Array
        input_err("#{item} is not Array") unless item.is_a?(Array)
        Structured.trace(Array) do
          return item.map { |i| convert_item(i, type.first, parent) }
        end

      when Hash
        input_err("#{item} is not Hash") unless item.is_a?(Hash)
        return item.map { |k, v|
          Structured.trace(Hash) do
            conv_key = convert_item(k, type.first.first, parent)
            conv_item = convert_item(v, type.first.last, parent)
            conv_item.receive_key(conv_key) if conv_item.is_a?(Structured)
            [ conv_key, conv_item ]
          end
        }.to_h

      when Regexp
        # Special case in which strings will be converted to Regexps
        return item if item.is_a?(Regexp)
        if item.is_a?(String)
          begin
            return Regexp.new(item)
          rescue RegexpError
            input_err("#{item} is not a valid regular expression")
          end
        end
        input_err("#{type} is not a Regexp")

      else
        return item if item.is_a?(type)
        # The only remaining hope for conversion is that type is Structured and
        # item is a hash
        return convert_structured(item, type, parent)
      end
    end

    # Receive hash values that are to be converted to Structured objects
    def convert_structured(item, type, parent)
      input_err("#{item.inspect} not a Structured hash") unless item.is_a?(Hash)
      unless type.include?(Structured) || type.include?(StructuredPolymorphic)
        input_err("#{type} is not a Structured class")
      end
      return type.new(item, parent)
    end


    def input_err(text)
      raise InputError, text
    end


    #
    # Prints out documentation for this class.
    #
    def explain(io = STDOUT)
      io.puts("Structured Class #{self}:")
      if @class_description
        io.puts("\n" + TextTools.line_break(@class_description, prefix: '  '))
      end
      io.puts

      each_element do |elt, data|
        io.puts(
          "  #{elt}: #{describe_type(data[:type])}" + \
          "#{data[:optional] ? ' (optional)' : ''}"
        )
        if data[:description]
          io.puts(TextTools.line_break(data[:description], prefix: '    '))
          io.puts()
        end
      end

      if @default_element
        io.puts(
          "  All other elements: #{describe_type(@default_element[:type])}"
        )
        if @default_element[:description]
          io.puts(TextTools.line_break(
            @default_element[:description], prefix: '    '
          ))
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

    #
    # Produces a template YAML file for this Structured object.
    def template(indent: '')
      res = "#{indent}# #{name}\n"
      if @class_description
        res << TextTools.line_break(@class_description, prefix: "#{indent}# ")
        res << "\n"
      end

      in_opt = false
      max_len = @elements.keys.map { |e| e.to_s.length }.max

      each_element do |elt, data|
        next if data[:optional] == :omit
        if data[:optional] && !in_opt
          res << "#{indent}#\n#{indent}# Optional\n"
          in_opt = true
        end

        res << "#{indent}#{elt}:"
        spacing = ' ' * (max_len - elt.to_s.length + 1)
        if data[:default]
          res << spacing << data[:default].inspect << "\n"
        else
          res << template_type(data[:type], indent, spacing)
        end
      end
      return res
    end

    #
    # @param type The Structured data type specification.
    # @param indent The indent string before new lines.
    # @param sp Spacing after the colon, if any.
    def template_type(type, indent, sp = ' ')
      res = ''
      case type
      when :boolean
        res << " true/false\n"
      when Class
        if type == String
          res << "#{sp}\"\"\n"
        elsif type.include?(Structured)
          res << "\n" << type.template(indent: indent + '  ')
        else
          res << "#{sp}# #{type}\n"
        end
      when Array
        if type.first == String
          res << "#{sp}[ \"\", ... ]\n"
        else
          res << "\n#{indent}  -" << template_type(type.first, indent + '  ')
        end
      when Hash
        if type.first.first == String
          res << "\n#{indent}  \"\":"
        else
          res << "\n#{indent}  [#{type.first.first}]:"
        end
        res << template_type(type.first.last, indent + '  ')
      end
      return res
    end
  end

  #
  # Includes ClassMethods.
  #
  def self.included(base)
    if base.is_a?(Class)
      base.extend(ClassMethods)
      base.reset_elements
    end
  end

  #
  # Enable tracing of object creation.
  #
  def self.trace(note)
    begin
      @trace_stack.push(note)
      return yield
    rescue InputError => e
      e.structured_stack ||= @trace_stack.dup
      raise e
    ensure
      @trace_stack.pop
    end
  end

  # Stack of traced items
  @trace_stack = []

end




require_relative 'structured-poly'
