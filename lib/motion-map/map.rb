module MotionMap
  class Map < Hash
    class << self
      def allocate
        super.instance_eval do
          @keys = []
          self
        end
      end
    
      def new(*args, &block)
        allocate.instance_eval do
          initialize(*args, &block)
          self
        end
      end    
      alias_method '[]', 'new'
        
      def for(*args, &block)
        if(args.size == 1 and block.nil?)
          return args.first if args.first.class == self
        end
        new(*args, &block)
      end

      def coerce(other)
        case other
          when MotionMap::Map
            other
          else
            allocate.update(other.to_hash)
        end
      end    
        
      # iterate over arguments in pairs smartly.
      #
      def each_pair(*args, &block)
        size = args.size
        parity = size % 2 == 0 ? :even : :odd
        first = args.first

        if block.nil?
          result = []
          block = lambda{|*kv| result.push(kv)}
        else
          result = args
        end

        return args if size == 0

        if size == 1
          if first.respond_to?(:each_pair)
            first.each_pair do |key, val|
              block.call(key, val)
            end
            return args
          end

          if first.respond_to?(:each_slice)
            first.each_slice(2) do |key, val|
              block.call(key, val)
            end
            return args
          end
          raise(ArgumentError, 'odd number of arguments for Map')
        end

        array_of_pairs = args.all?{|a| a.is_a?(Array) and a.size == 2}

        if array_of_pairs
          args.each do |pair|
            key, val, *ignored = pair
            block.call(key, val)
          end
        else
          0.step(args.size - 1, 2) do |a|
            key = args[a]
            val = args[a + 1]
            block.call(key, val)
          end
        end

        args
      end
    
      def intersection(a, b)
        a, b, i = MotionMap::Map.for(a), MotionMap::Map.for(b), MotionMap::Map.new
        a.depth_first_each{|key, val| i.set(key, val) if b.has?(key)}
        i
      end

      def match(haystack, needle)
        intersection(haystack, needle) == needle
      end    
    end  
  
    def keys
      @keys ||= []
    end
  
    def initialize(*args, &block)
      case args.size
        when 0
          super(&block)
        when 1
          first = args.first
          case first
            when nil, false
              nil
            when Hash             
              initialize_from_hash(first)
            when Array      
              initialize_from_array(first)
            else
              if first.respond_to?(:to_hash)
                initialize_from_hash(first.to_hash)
              else
                initialize_from_hash(first)
              end
          end        
        else
          initialize_from_array(args)
      end
    end 
  
    def initialize_from_hash(hash)
      map = self
      map.update(hash)
      map.default = hash.default
    end

    def initialize_from_array(array)
      map = self    
      MotionMap::Map.each_pair(array){|key, val| map[key] = val}
    end
   
    def klass
      self.class
    end

    def self.map_for(hash)
      hash = klass.coerce(hash)
      hash.default = hash.default
      hash
    end
    def map_for(hash)
      klass.map_for(hash)
    end
   
    def self.convert_key(key)
      key = key.kind_of?(Symbol) ? key.to_s : key
    end

    def convert_key(key)
      if klass.respond_to?(:convert_key)
        klass.convert_key(key)
      else
        MotionMap::Map.convert_key(key)
      end
    end

    def self.convert_value(value)
      case value
        when Hash
          coerce(value)
        when Array
          value.map!{|v| convert_value(v)}
        else
          value
      end
    end
    def convert_value(value)
      if klass.respond_to?(:convert_value)
        klass.convert_value(value)
      else
        MotionMap::Map.convert_value(value)
      end
    end
    alias_method('convert_val', 'convert_value')
   
   
    def convert(key, val)
      [convert_key(key), convert_value(val)]
    end

    def copy
      default = self.default
      self.default = nil
      copy = Marshal.load(Marshal.dump(self)) rescue Dup.bind(self).call()
      copy.default = default
      copy
    ensure
      self.default = default
    end

    Dup = instance_method(:dup) unless defined?(Dup)

    def dup
      copy
    end

    def clone
      copy
    end

    def default(key = nil)
      key.is_a?(Symbol) && include?(key = key.to_s) ? self[key] : super
    end

    def default=(value)
      raise ArgumentError.new("Map doesn't work so well with a non-nil default value!") unless value.nil?
    end

    # writer/reader methods
    #
    alias_method '__set__', '[]=' unless method_defined?('__set__')
    alias_method '__get__', '[]' unless method_defined?('__get__')
    alias_method '__update__', 'update' unless method_defined?('__update__')

    def []=(key, val)
      key, val = convert(key, val)
      keys.push(key) unless has_key?(key)
      __set__(key, val)
    end
    alias_method 'store', '[]='

    def [](key)
      key = convert_key(key)
      __get__(key)
    end

    def fetch(key, *args, &block)
      key = convert_key(key)
      super(key, *args, &block)
    end

    def key?(key)
      super(convert_key(key))
    end
    alias_method 'include?', 'key?'
    alias_method 'has_key?', 'key?'
    alias_method 'member?', 'key?'      
  
    def update(*args)
      MotionMap::Map.each_pair(*args){|key, val| store(key, val)}
      self
    end
    alias_method 'merge!', 'update'

    def merge(*args)
      copy.update(*args)
    end
    alias_method '+', 'merge'

    def reverse_merge(hash)
      map = copy
      map.each{|key, val| MotionMap::Map[key] = val unless MotionMap::Map.key?(key)}
      map
    end

    def reverse_merge!(hash)
      replace(reverse_merge(hash))
    end

    def values
      array = []
      keys.each{|key| array.push(self[key])}
      array
    end
    alias_method 'vals', 'values'

    def values_at(*keys)
      keys.map{|key| self[key]}
    end

    def first
      [keys.first, self[keys.first]]
    end

    def last
      [keys.last, self[keys.last]]
    end

    # iterator methods
    #
    def each_with_index
      keys.each_with_index{|key, index| yield([key, self[key]], index)}
      self
    end

    def each_key
      keys.each{|key| yield(key)}
      self
    end

    def each_value
      keys.each{|key| yield self[key]}
      self
    end

    def each
      keys.each{|key| yield(key, self[key])}
      self
    end
    alias_method 'each_pair', 'each'

    # mutators
    #
    def delete(key)
      key = convert_key(key)
      keys.delete(key)
      super(key)
    end

    def clear
      keys.clear
      super
    end

    def delete_if
      to_delete = []
      keys.each{|key| to_delete.push(key) if yield(key,self[key])}
      to_delete.each{|key| delete(key)}
      self
    end

    # See: https://github.com/rubinius/rubinius/blob/98c516820d9f78bd63f29dab7d5ec9bc8692064d/kernel/common/hash19.rb#L476-L484
    def keep_if( &block )
      raise RuntimeError.new( "can't modify frozen #{ self.class.name }" ) if frozen?
      return to_enum( :keep_if ) unless block_given?
      each { | key , val | delete key unless yield( key , val ) }
      self
    end

    def replace(*args)
      clear
      update(*args)
    end

    # ordered container specific methods
    #
    def shift
      unless empty?
        key = keys.first
        val = delete(key)
        [key, val]
      end
    end

    def unshift(*args)
      MotionMap::Map.each_pair(*args) do |key, val|
        if key?(key)
          delete(key)
        else
          keys.unshift(key)
        end
        __set__(key, val)
      end
      self
    end

    def push(*args)
      MotionMap::Map.each_pair(*args) do |key, val|
        if key?(key)
          delete(key)
        else
          keys.push(key)
        end
        __set__(key, val)
      end
      self
    end

    def pop
      unless empty?
        key = keys.last
        val = delete(key)
        [key, val]
      end
    end

    # equality / sorting / matching support 
    #
    def ==(other)
      case other
        when MotionMap::Map
          return false if keys != other.keys
          super(other)

        when Hash
          self == MotionMap::Map.from_hash(other, self)

        else
          false
      end
    end

    def <=>(other)
      cmp = keys <=> klass.coerce(other).keys
      return cmp unless cmp.zero?
      values <=> klass.coerce(other).values
    end

    def =~(hash)
      to_hash == klass.coerce(hash).to_hash
    end

    # reordering support
    #
    def reorder(order = {})
      order = MotionMap::Map.for(order)
      map = MotionMap::Map.new
      keys = order.depth_first_keys | depth_first_keys
      keys.each{|key| map.set(key, get(key))}
      map
    end

    def reorder!(order = {})
      replace(reorder(order))
    end

    # support for building ordered hasshes from a Map's own image
    #
    def self.from_hash(hash, order = nil)
      map = MotionMap::Map.for(hash)
      map.reorder!(order) if order
      map
    end

    def invert
      inverted = klass.allocate
      inverted.default = self.default
      keys.each{|key| inverted[self[key]] = key }
      inverted
    end

    def reject(&block)
      dup.delete_if(&block)
    end

    def reject!(&block)
      hash = reject(&block)
      self == hash ? nil : hash
    end

    def select
      array = []
      each{|key, val| array << [key,val] if yield(key, val)}
      array
    end

    def inspect(*args, &block)
      super.inspect
    end

    def to_hash
      hash = Hash.new(default)
      each do |key, val|
        val = val.to_hash if val.respond_to?(:to_hash)
        hash[key] = val
      end
      hash
    end

    def to_array
      array = []
      each{|*pair| array.push(pair)}
      array
    end
    alias_method 'to_a', 'to_array'

    def to_list
      list = []
      each_pair do |key, val|
        list[key.to_i] = val if(key.is_a?(Numeric) or key.to_s =~ %r/^\d+$/)
      end
      list
    end

    def to_s
      to_array.to_s
    end

    # a sane method missing that only supports writing values or reading
    # *previously set* values
    #
    def method_missing(*args, &block)
      method = args.first.to_s
      case method
        when /=$/
          key = args.shift.to_s.chomp('=')
          value = args.shift
          self[key] = value
        when /\?$/
          key = args.shift.to_s.chomp('?')
          self.has?( key )
        else
          key = method
          unless has_key?(key)
            return(block ? fetch(key, &block) : super(*args))
          end
          self[key]
      end
    end

    def respond_to?(method, *args, &block)
      has_key = has_key?(method)
      setter = method.to_s =~ /=\Z/o
      !!((!has_key and setter) or has_key or super)
    end

    def id
      return self[:id] if has_key?(:id)
      return self[:_id] if has_key?(:_id)
      raise NoMethodError
    end

    # support for compound key indexing and depth first iteration
    #
    def get(*keys)
      keys = key_for(keys)

      if keys.size <= 1
        if !self.has_key?(keys.first) && block_given?
          return yield
        else
          return self[keys.first]
        end
      end

      keys, key = keys[0..-2], keys[-1]
      collection = self

      keys.each do |k|
        if MotionMap::Map.collection_has?(collection, k)
          collection = MotionMap::Map.collection_key(collection, k)
        else
          collection = nil
        end

        unless collection.respond_to?('[]')
          leaf = collection
          return leaf
        end
      end

      if !MotionMap::Map.collection_has?(collection, key) && block_given?
        default_value = yield
      else
        MotionMap::Map.collection_key(collection, key)
      end
    end

    def has?(*keys)
      keys = key_for(keys)
      collection = self

      return MotionMap::Map.collection_has?(collection, keys.first) if keys.size <= 1

      keys, key = keys[0..-2], keys[-1]

      keys.each do |k|
        if MotionMap::Map.collection_has?(collection, k)
          collection = MotionMap::Map.collection_key(collection, k)
        else
          collection = nil
        end

        return collection unless collection.respond_to?('[]')
      end

      return false unless(collection.is_a?(Hash) or collection.is_a?(Array))

      MotionMap::Map.collection_has?(collection, key)
    end

    def self.blank?(value)
      return value.blank? if value.respond_to?(:blank?)

      case value
        when String
          value.strip.empty?
        when Numeric
          value == 0
        when false
          true
        else
          value.respond_to?(:empty?) ? value.empty? : !value
      end
    end

    def blank?(*keys)
      return empty? if keys.empty?
      !has?(*keys) or MotionMap::Map.blank?(get(*keys))
    end

    def self.collection_key(collection, key, &block)
      case collection
        when Array
          begin
            key = Integer(key)
          rescue
            raise(IndexError, "(#{ collection.inspect })[#{ key.inspect }]")
          end
          collection[key]

        when Hash
          collection[key]

        else
          raise(IndexError, "(#{ collection.inspect })[#{ key.inspect }]")
      end
    end

    def collection_key(*args, &block)
      MotionMap::Map.collection_key(*args, &block)
    end

    def self.collection_has?(collection, key, &block)
      has_key =
        case collection
          when Array
            key = (Integer(key) rescue -1)
            (0...collection.size).include?(key)

          when Hash
            collection.has_key?(key)

          else
            raise(IndexError, "(#{ collection.inspect })[#{ key.inspect }]")
        end

      block.call(key) if(has_key and block)

      has_key
    end

    def collection_has?(*args, &block)
      MotionMap::Map.collection_has?(*args, &block)
    end

    def self.collection_set(collection, key, value, &block)
      set_key = false

      case collection
        when Array
          begin
            key = Integer(key)
          rescue
            raise(IndexError, "(#{ collection.inspect })[#{ key.inspect }]=#{ value.inspect }")
          end
          set_key = true
          collection[key] = value

        when Hash
          set_key = true
          collection[key] = value

        else
          raise(IndexError, "(#{ collection.inspect })[#{ key.inspect }]=#{ value.inspect }")
      end

      block.call(key) if(set_key and block)

      [key, value]
    end

    def collection_set(*args, &block)
      MotionMap::Map.collection_set(*args, &block)
    end

    def set(*args)
      case
        when args.empty?
          return []
        when args.size == 1 && args.first.is_a?(Hash)
          hash = args.shift
        else
          hash = {}
          value = args.pop
          key = Array(args).flatten
          hash[key] = value
      end

      strategy = hash.map{|key, value| [Array(key), value]}

      strategy.each do |key, value|
        leaf_for(key, :autovivify => true) do |leaf, k|
          MotionMap::Map.collection_set(leaf, k, value)
        end
      end

      self
    end

    def add(*args)
      case
        when args.empty?
          return []
        when args.size == 1 && args.first.is_a?(Hash)
          hash = args.shift
        else
          hash = {}
          value = args.pop
          key = Array(args).flatten
          hash[key] = value
      end

      exploded = MotionMap::Map.explode(hash)

      exploded[:branches].each do |key, type|
        set(key, type.new) unless get(key).is_a?(type)
      end

      exploded[:leaves].each do |key, value|
        set(key, value)
      end

      self
    end

    def self.explode(hash)
      accum = {:branches => [], :leaves => []}

      hash.each do |key, value|
        MotionMap::Map._explode(key, value, accum)
      end

      branches = accum[:branches]
      leaves = accum[:leaves]

      sort_by_key_size = proc{|a,b| a.first.size <=> b.first.size}

      branches.sort!(&sort_by_key_size)
      leaves.sort!(&sort_by_key_size)

      accum
    end

    def self._explode(key, value, accum = {:branches => [], :leaves => []})
      key = Array(key).flatten

      case value
        when Array
          accum[:branches].push([key, Array])

          value.each_with_index do |v, k|
            MotionMap::Map._explode(key + [k], v, accum)
          end

        when Hash
          accum[:branches].push([key, MotionMap::Map])
          value.each do |k, v|
            MotionMap::Map._explode(key + [k], v, accum)
          end

        else
          accum[:leaves].push([key, value])
      end

      accum
    end

    def self.add(*args)
      args.flatten!
      args.compact!

      MotionMap::Map.for(args.shift).tap do |map|
        args.each{|arg| map.add(arg)}
      end
    end

    def self.combine(*args)
      MotionMap::Map.add(*args)
    end

    def combine!(*args, &block)
      add(*args, &block)
    end

    def combine(*args, &block)
      dup.tap do |map|
        map.combine!(*args, &block)
      end
    end

    def leaf_for(key, options = {}, &block)
      leaf = self
      key = Array(key).flatten
      k = key.first

      key.each_cons(2) do |a, b|
        exists = MotionMap::Map.collection_has?(leaf, a)

        case b
          when Numeric
            if options[:autovivify]
              MotionMap::Map.collection_set(leaf, a, Array.new) unless exists
            end

          when String, Symbol
            if options[:autovivify]
              MotionMap::Map.collection_set(leaf, a, MotionMap::Map.new) unless exists
            end
        end

        leaf = MotionMap::Map.collection_key(leaf, a)
        k = b
      end

      block ? block.call(leaf, k) : [leaf, k]
    end

    def rm(*args)
      paths, path = args.partition{|arg| arg.is_a?(Array)}
      paths.push(path)

      paths.each do |path|
        if path.size == 1
          delete(*path)
          next
        end

        branch, leaf = path[0..-2], path[-1]
        collection = get(branch)

        case collection
          when Hash
            key = leaf
            collection.delete(key)
          when Array
            index = leaf
            collection.delete_at(index)
          else
            raise(IndexError, "(#{ collection.inspect }).rm(#{ path.inspect })")
        end
      end
      paths
    end

    def forcing(forcing=nil, &block)
      @forcing ||= nil

      if block
        begin
          previous = @forcing
          @forcing = forcing
          block.call()
        ensure
          @forcing = previous
        end
      else
        @forcing
      end
    end

    def forcing?(forcing=nil)
      @forcing ||= nil
      @forcing == forcing
    end

    def apply(other)
      MotionMap::Map.for(other).depth_first_each do |keys, value|
        set(keys => value) unless !get(keys).nil?
      end
      self
    end

    def self.alphanumeric_key_for(key)
      return key if key.is_a?(Numeric)

      digity, stringy, digits = %r/^(~)?(\d+)$/iomx.match(key).to_a

      digity ? stringy ? String(digits) : Integer(digits) : key
    end

    def alphanumeric_key_for(key)
      MotionMap::Map.alphanumeric_key_for(key)
    end

    def self.key_for(*keys)
      return keys.flatten
    end

    def key_for(*keys)
      self.class.key_for(*keys)
    end

    ## TODO - technically this returns only leaves so the name isn't *quite* right.  re-factor for 3.0
    #
    def self.depth_first_each(enumerable, path = [], accum = [], &block)
      self.pairs_for(enumerable) do |key, val|
        path.push(key)
        if((val.is_a?(Hash) or val.is_a?(Array)) and not val.empty?)
          MotionMap::Map.depth_first_each(val, path, accum)
        else
          accum << [path.dup, val]
        end
        path.pop()
      end
      if block
        accum.each{|keys, val| block.call(keys, val)}
      else
        accum
      end
    end

    def self.depth_first_keys(enumerable, path = [], accum = [], &block)
      accum = self.depth_first_each(enumerable, path = [], accum = [], &block)
      accum.map!{|kv| kv.first}
      accum
    end

    def self.depth_first_values(enumerable, path = [], accum = [], &block)
      accum = self.depth_first_each(enumerable, path = [], accum = [], &block)
      accum.map!{|kv| kv.last}
      accum
    end

    def self.pairs_for(enumerable, *args, &block)
      if block.nil?
        pairs, block = [], lambda{|*pair| pairs.push(pair)}
      else
        pairs = false
      end

      result =
        case enumerable
          when Hash
            enumerable.each_pair(*args, &block)
          when Array
            enumerable.each_with_index(*args) do |val, key|
              block.call(key, val)
            end
          else
            enumerable.each_pair(*args, &block)
        end

      pairs ? pairs : result
    end

    def self.breadth_first_each(enumerable, accum = [], &block)
      levels = []

      keys = MotionMap::Map.depth_first_keys(enumerable)

      keys.each do |key|
        key.size.times do |i|
          k = key.slice(0, i + 1)
          level = k.size - 1
          levels[level] ||= Array.new
          last = levels[level].last
          levels[level].push(k) unless last == k
        end
      end

      levels.each do |level|
        level.each do |key|
          val = enumerable.get(key)
          block ? block.call(key, val) : accum.push([key, val])
        end
      end

      block ? enumerable : accum
    end

    def self.keys_for(enumerable)
      keys = enumerable.respond_to?(:keys) ? enumerable.keys : Array.new(enumerable.size){|i| i}
    end

    def depth_first_each(*args, &block)
      MotionMap::Map.depth_first_each(enumerable=self, *args, &block)
    end

    def depth_first_keys(*args, &block)
      MotionMap::Map.depth_first_keys(enumerable=self, *args, &block)
    end

    def depth_first_values(*args, &block)
      MotionMap::Map.depth_first_values(enumerable=self, *args, &block)
    end

    def breadth_first_each(*args, &block)
      MotionMap::Map.breadth_first_each(enumerable=self, *args, &block)
    end

    # Make RM Not happy ;-(
    # def contains(other)
    #   other = other.is_a?(Hash) ? MotionMap::Map.coerce(other) : other
    #   breadth_first_each{|key, value| return true if value == other}
    #   return false
    # end
    # alias_method 'contains?', 'contains'
  end
end