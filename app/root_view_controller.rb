class RootViewController < UIViewController
	def viewDidLoad
    view = UIScrollView.alloc.init
    view.backgroundColor = UIColor.whiteColor
    m = Map.new(a:10, b:20, c:{d:30} )
    # Map = {a:10, b:20}
		view.contentSize = [320, m.count*200]
		  		
		i = 0
		m.each_pair do |k,v|
			label = UILabel.alloc.initWithFrame( [[10, 10+i*40], [320, 40]] )
			label.text = "#{k}:#{v}"
			self.view.addSubview(label)
			i += 1
		end
	end
end