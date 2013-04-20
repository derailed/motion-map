describe MotionMap::Map do
  extend MapHelper
  
  describe 'constructor' do
    it 'supports bare constructor' do
      map = MotionMap::Map.new
      map .count.should == 0
    end
  
    it 'can take a hash' do
      map = MotionMap::Map.new( {} )
      map.count.should == 0
    end
    
    it 'can take an empty array' do
      array = []
      map = MotionMap::Map.new( array )
      map.count.should == 0
      map = MotionMap::Map.new( *array )
      map.count.should == 0      
    end
    
    it 'deals with nil correctly' do
      map = MotionMap::Map.new( nil )
      map.count.should == 0
      map = MotionMap::Map.new( false )
      map.count.should == 0
    end
    
    it 'accepts an even sized array' do
      arrays = [
        [ %w( k v ), %w( key val ) ],
        [ %w( k v ), %w( key val ), %w( a b ) ],
        [ %w( k v ), %w( key val ), %w( a b ), %w( x y ) ]
      ]
      expectations = [1, 2, 2]
      i = 0
      arrays.each do |array|
        map = MotionMap::Map.new(array)
        map.count.should == expectations[i]
        map = MotionMap::Map.new(*array)
        map.count.should == expectations[i]
        i += 1
      end      
    end
    
    it 'can deal with [] as new' do
      list = [
        [],
        [{}],
        [[:key, :val]],
        [:key, :val]
      ]
      list.each do |args|
        map = MotionMap::Map[*args]
        map.class.should == MotionMap::Map
        MotionMap::Map.new(*args).should == map
      end      
    end
  end
    
  describe 'iterators' do
    it 'yields pairs in order' do
      map = new_int_map
      i = 0
      map.each do |key, val|
        key.should == i.to_s
        val.should == i
        i += 1
      end
    end  
    
    it 'preserves ordering' do
      map    = new_int_map(n=2048)
      values = Array.new(n) {|i| i}
      keys   = values.map{|value| value.to_s}
      map.keys.size.should == n
      map.keys.should      == keys
      map.values.should    == values      
    end  
  end
  
  describe 'accessors' do
    it 'Maps string/symbol indifferent for simple look-ups' do
      map = MotionMap::Map.new
      map[:k]  = :v
      map['a'] = 'b'
      map[:k].should      == :v
      map[:k.to_s].should == :v
      map[:a].should      == 'b'
      map[:a.to_s].should == 'b'
    end
    
    it 'Maps string/symbol indifferent for recursive look-ups' do
      map = MotionMap::Map[:a => {:b => {:c => 42}}]      
      map[:a].should            == {:b => {:c => 42}}
      map[:a][:b][:c].should    == 42
      map['a'][:b][:c].should   == 42
      map['a']['b'][:c].should  == 42
      map['a']['b']['c'].should == 42
      map[:a]['b'][:c].should   == 42
      map[:a]['b']['c'].should  == 42
      map[:a][:b]['c'].should   == 42
      map['a'][:b]['c'].should  == 42
        
      map = MotionMap::Map[:a => [{:b => 42}]]
      map['a'].class.should    == Array
      map['a'][0].class.should == MotionMap::Map
      map['a'][0]['b'].should  == 42
        
      map = MotionMap::Map[:a => [ {:b => 42}, [{:c => 'forty-two'}] ]]
      map['a'].class.should      == Array
      map['a'][0].class.should   == MotionMap::Map
      map['a'][1].class.should   == Array
      map['a'][0]['b'].should    == 42
      map['a'][1][0]['c'].should == 'forty-two'
    end        
  end
  
  describe 'shift' do
    it 'supports shift like a good ordered container' do
      map = MotionMap::Map.new
      10.times do |i|
        key, val = i.to_s, i
        map.unshift(key, val)
        map[key].should              == val
        map.keys.first.to_s.should   == key.to_s
        map.values.first.to_s.should == val.to_s
      end
  
      map = MotionMap::Map.new
      args = []
      10.times do |i|
        key, val = i.to_s, i
        args.unshift([key, val])
      end
      map.unshift(*args)
      10.times do |i|
        key, val = i.to_s, i
        map[key].should == val
        map.keys[i].to_s.should   == key.to_s
        map.values[i].to_s.should == val.to_s
      end
    end
  end
  
  describe 'comparator' do
    it 'supports match operator, which can make testing hash equality simpler!' do
      map  = new_int_map
      hash = new_int_hash
      map.should =~ hash
    end    
    
    it 'supports inheritence without cycles' do
      c = Class.new(MotionMap::Map){}
      o = c.new
      MotionMap::Map.should === o
    end
    
    it 'captures equality correctly' do
      a = MotionMap::Map.new
      b = MotionMap::Map.new
      a.should == b
      a.should != 42
      b[:k] = :v
      a.should != b
    end      
  end
  
  describe 'keys as methods' do
    it 'works with simple usage' do
      a = MotionMap::Map.new( k: :v)
      a.k.should == :v
    end
  
    it 'works with complexusage' do
      a = MotionMap::Map.new( k: {a: {b: 10}} )
      a.k.a.b.should == 10
    end    
  end  
  
  describe 'subclassing' do
    it 'insures subclassing and clobbering initialize does not kill nested coersion' do
      c = Class.new(MotionMap::Map){ def initialize(arg) end }
      o = c.new(42)
      o.class.should == c
      o.update(:k => {:a => :b})
      o.size.should == 1
    end    
    
    it 'ensures that subclassing does not kill class level coersion' do
      c = Class.new(MotionMap::Map){ }
      o = c.for(MotionMap::Map.new)
      o.class.should == c
  
      d = Class.new(c)
      o = d.for(MotionMap::Map.new)
      o.class.should == d
    end    
  end
  
  describe '#to_list' do
    it 'insures Maps can be converted to lists with numeric indexes' do
      m = MotionMap::Map[0, :a, 1, :b, 2, :c]
      m.to_list.should == [:a, :b, :c]
    end
  end    
  
  describe 'method_missing' do
    it 'ensures method_missing hacks allow setting values, but not getting them until they are set' do
      m = MotionMap::Map.new
      (m.missing rescue $!).class.should == NoMethodError
      m.missing = :val
      m[:missing].should == :val
      m.missing.should == :val
    end
  
    it 'ensures method_missing hacks have sane respond_to? semantics' do
      m = MotionMap::Map.new
      m.respond_to?(:missing).should == false
      m.respond_to?(:missing=).should == true
      m.missing = :val
      m.respond_to?(:missing).should  == true
      m.respond_to?(:missing=).should == true
    end
    
    it 'ensures method missing with a block delegatets to fetch' do
      m = MotionMap::Map.new
      m.missing{ :val }.should == :val
      m.has_key?(:key).should == false
    end
  end  
  
  describe 'compound keys' do
    it 'Maps support compound key/val setting' do
      m = MotionMap::Map.new
      m.set(:a, :b, :c, 42)
      m.get(:a, :b, :c).should == 42
  
      m = MotionMap::Map.new
      m.set([:a, :b, :c], 42)
      m.get(:a, :b, :c) == 42
  
      m = MotionMap::Map.new
      m.set([:a, :b, :c] => 42)
      m.get(:a, :b, :c) == 42
  
      m = MotionMap::Map.new
      m.set([:x, :y, :z] => 42.0, [:A, 2] => 'forty-two')
      m[:A].class.should     == Array
      m[:A].size.should      == 3
      m[:A][2].should        == 'forty-two'
      m[:x][:y].class.should == MotionMap::Map
      m[:x][:y][:z].should   == 42.0
  
      MotionMap::Map.new.tap{|m| m.set}.should =~ {}
      MotionMap::Map.new.tap{|m| m.set({})}    =~ {}
    end 
  end
  
  describe '#get' do
    it 'supports providing a default value in a block' do
      m = MotionMap::Map.new
      m.set(:a, :b, :c, 42)
      m.set(:z, 1)
  
      m.get(:x){1}.should         == 1
      m.get(:z){2}.should         == 1
      m.get(:a, :b, :d){1}.should == 1
      m.get(:a, :b, :c){1}.should == 42
      m.get(:a, :b){1}.should     == MotionMap::Map[{:c => 42}]
      m.get(:a, :aa){1}.should    == 1
    end    
    
    it 'ensures setting a sub-container does not eff up the container values' do
      m = MotionMap::Map.new
      m.set(:array => [0,1,2])
      m.get(:array, 0).should == 0
      m.get(:array, 1).should == 1
      m.get(:array, 2).should == 2
  
      m.set(:array, 2, 42)
      m.get(:array, 0).should == 0
      m.get(:array, 1).should == 1
      m.get(:array, 2).should == 42
    end    
  end
  
  describe 'merging' do
    it 'ensures #apply selectively merges non-nil values' do
      m = MotionMap::Map.new(:array => [0, 1], :hash => {:a => false, :b => nil, :c => 42})
      defaults = MotionMap::Map.new(:array => [nil, nil, 2], :hash => {:b => true})
  
      m.apply(defaults)
      m[:array].should == [0,1,2]
      m[:hash].should  =~ {:a => false, :b => true, :c => 42}
  
      m = MotionMap::Map.new
      m.apply :key => [{:key => :val}]
      m[:key].class.should    == Array
      m[:key][0].class.should == MotionMap::Map
    end  
    
    it 'ensures #add overlays the leaves of one hash onto another without nuking branches' do
      m = MotionMap::Map.new
  
      m.add(
        :comments => [
          { :body => 'a' },
          { :body => 'b' },
        ],
  
        [:comments, 0] => {'title' => 'teh title', 'description' => 'description'},
        [:comments, 1] => {'description' => 'description'},
      )
      m.should =~
          {"comments"=>
            [{"body"=>"a", "title"=>"teh title", "description"=>"description"},
               {"body"=>"b", "description"=>"description"}]}
  
      m = MotionMap::Map.new
      m.add(
        [:a, :b, :c] => 42,
        [:a, :b] => {:d => 42.0}
      )
      m.should =~ {"a"=>{"b"=>{"c"=>42, "d"=>42.0}}}
  
      MotionMap::Map.new.tap{|m| m.add}.should     =~ {}
      MotionMap::Map.new.tap{|m| m.add({})}.should =~ {}
    end      
    
    it 'ensures that Map.combine is teh sweet' do
      {
        [{:a => {:b => 42}}, {:a => {:c => 42.0}}]               => {"a"=>{"b"=>42, "c"=>42.0}},
        [{:a => {:b => 42}}, {:a => {:c => 42.0, :d => [1]}}]    => {"a"=>{"b"=>42, "d"=>[1], "c"=>42.0}},
        [{:a => {:b => 42}}, {:a => {:c => 42.0, :d => {0=>1}}}] => {"a"=>{"b"=>42, "d"=>{0=>1}, "c"=>42.0}}          
      }.each do |args, expected|
        MotionMap::Map.combine(*args).should =~ expected
      end
    end    
  end
  
  describe 'traversal' do
    it 'supports depth_first_each' do
      m      = MotionMap::Map.new
      prefix = %w[ a b c ]
      keys   = []
      n      = 0.42
  
      10.times do |i|
        key = prefix + [i]      
        val = n
        keys.push(key)
        m.set(key => val)
        n *= 10
      end
      m.get(:a).class.should         == MotionMap::Map
      m.get(:a, :b).class.should     == MotionMap::Map
      m.get(:a, :b, :c).class.should == Array
  
      n = 0.42
      m.depth_first_each do |key, val|
        key.should == keys.shift
        val.should == n
        n *= 10
      end
    end  
    
    it 'ensures #each_pair works on arrays' do
      each  = []
      array = %w( a b c )
      MotionMap::Map.each_pair(array){|k,v| each.push(k,v)}
      each.should == ['a', 'b', 'c', nil]
    end
    
    it 'supports breath_first_each' do
      m = MotionMap::Map[
        'hash'         , {'x' => 'y'},
        'nested hash'  , {'nested' => {'a' => 'b'}},
        'array'        , [0, 1, 2],
        'nested array' , [[3], [4], [5]],
        'string'       , '42'
      ]
  
      accum = []
      m.breadth_first_each(MotionMap::Map){|k, v| accum.push([k, v])}
      expected =
        [
         [["hash"], {"x"=>"y"}],
         [["nested hash"], {"nested"=>{"a"=>"b"}}],
         [["array"], [0, 1, 2]],
         [["nested array"], [[3], [4], [5]]],
         [["string"], "42"],
         
         [["hash", "x"], "y"],
         [["nested hash", "nested"], {"a"=>"b"}],
         [["array", 0], 0],
         [["array", 1], 1],
         [["array", 2], 2],
         [["nested array", 0], [3]],
         [["nested array", 1], [4]],
         [["nested array", 2], [5]],
         
         [["nested hash", "nested", "a"], "b"],
         [["nested array", 0, 0], 3],
         [["nested array", 1, 0], 4],
         [["nested array", 2, 0], 5]
        ]
       accum.should == expected
    end    
  end
  
  describe '#contains' do
    it 'handles needle-in-a-haystack like #contains? method' do
      haystack = MotionMap::Map[
        'hash'         , {'x' => 'y'},
        'nested hash'  , {'nested' => {'a' => 'b'}},
        'array'        , [0, 1, 2],
        'nested array' , [[3], [4], [5]],
        'string'       , '42'
      ]
  
      needles = [
        {'x' => 'y'},
        {'nested' => {'a' => 'b'}},
        {'a' => 'b'},
        [0,1,2],
        [[3], [4], [5]],
        [3],
        [4],
        [5],
        '42',
        0,1,2,
        3,4,5
      ]
  
      needles.each do |needle|
        haystack.contains?(needle).should == true
      end
    end
  end
  
  it 'ensures #blank? method that is sane' do
    m = MotionMap::Map.new(:a => 0, :b => ' ', :c => '', :d => {}, :e => [], :f => false)
    m.each do |key, val|
      m.blank?(key).should == true
    end
  
    m = MotionMap::Map.new(:a => 1, :b => '_', :d => {:k=>:v}, :e => [42], :f => true)
    m.each do |key, val|
      m.blank?(key).should == false
    end
    MotionMap::Map.new.blank?.should == true
  end  
  
  it 'ensures self referential Maps do not make #inspect puke' do
    a = MotionMap::Map.new
    b = MotionMap::Map.new
  
    b[:a] = a
    a[:b] = b
  
    begin
      a.inspect
      b.inspect
      true.should == true
    rescue => boom
      fail boom
    end
  end
    
  it 'has a clever little rm operator' do
    m = MotionMap::Map.new
    m.set :a, :b, 42
    m.set :x, :y, 42
    m.set :x, :z, 42
    m.set :array, [0,1,2]
  
    m.rm(:x, :y)
    m.get(:x).should =~ {:z => 42}
    
    m.rm(:a, :b)
    m.get(:a).should =~ {}
  
    m.rm(:array, 0)
    m.get(:array).should == [1,2]
    m.rm(:array, 1)
    m.get(:array).should == [1]
    m.rm(:array, 0)
    m.get(:array).should == []
  
    m.rm(:array)
    m.get(:array).should == nil
  
    m.rm(:a)
    m.get(:a).should == nil
  
    m.rm(:x)
    m.get(:x).should == nil
  end
  
  it 'Maps a clever little question method' do
    m = MotionMap::Map.new
    m.set(:a, :b, :c, 42)
    m.set([:x, :y, :z] => 42.0, [:A, 2] => 'forty-two')
  
    m.b?.should     == false
    m.a?.should     == true
    m.a.b?.should   == true
    m.a.b.c?.should == true
    m.a.b.d?.should == false
  
    m.x?.should     == true
    m.x.y?.should   == true
    m.x.y.z?.should == true
    m.y?.should     == false
  
    m.A?.should     == true
   end    
end