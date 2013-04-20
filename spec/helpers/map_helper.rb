module MapHelper
  def new_int_map(n = 1024)
    MotionMap::Map.new.tap do |m|
      n.times{|i| m[i.to_s] = i}
    end
  end
  
  def new_int_hash(n = 1024)
    hash = Hash.new
    n.times{|i| hash[i.to_s] = i}
    hash
  end  
end