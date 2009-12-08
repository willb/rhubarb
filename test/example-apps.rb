class QmfClicker
  include ::SPQR::Manageable
  
  def QmfClicker.find_by_id(oid)
    @singleton ||= QmfClicker.new
    @singleton
  end
  
  def QmfClicker.find_all
    @singleton ||= QmfClicker.new
    [@singleton]
  end
  
  def initialize
    @clicks = 0
  end
  
  def click(args)
    @clicks = @clicks.succ
  end
  
  expose :click do |args| 
  end
  
  qmf_statistic :clicks, :int
  
  qmf_package_name :example
  qmf_class_name :QmfClicker
end

class QmfHello
  include ::SPQR::Manageable
  
  def QmfHello.find_by_id(oid)
    @qmf_hellos ||= [QmfHello.new]
    @qmf_hellos[0]
  end
  
  def QmfHello.find_all
    @qmf_hellos ||= [QmfHello.new]
    @qmf_hellos
  end

  def hello(args)
    args["result"] = "Hello, #{args['name']}!"
  end

  expose :hello do |args|
    args.declare :name, :lstr, :in
    args.declare :result, :lstr, :out
  end
  
  qmf_package_name :example
  qmf_class_name :QmfHello
end

class QmfDummyProp
  include ::SPQR::Manageable

  def QmfDummyProp.find_by_id(oid)
    @qmf_dps ||= [QmfDummyProp.new]
    @qmf_dps[0]
  end
  
  def QmfDummyProp.find_all
    @qmf_dps ||= [QmfDummyProp.new]
    @qmf_dps
  end
  
  def service_name
    "DummyPropService"
  end
  
  qmf_property :service_name, :lstr

  qmf_class_name :QmfDummyProp
  qmf_package_name :example
end


class QmfIntegerProp
  include ::SPQR::Manageable 

  SIZE = 12
 
  def initialize(oid)
    @int_id = oid
  end

  def spqr_object_id
    @int_id
  end
  
  def QmfIntegerProp.gen_objects(ct)
    objs = []
    ct.times do |x|
      objs << (new(x))
    end
    objs
  end

  def QmfIntegerProp.find_by_id(oid)
    @qmf_ips ||= gen_objects(SIZE)
    @qmf_ips[oid]
  end
  
  def QmfIntegerProp.find_all
    @qmf_ips ||= gen_objects(SIZE)
    @qmf_ips
  end

  def next(args)
    args['result'] = QmfIntegerProp.find_by_id((@int_id + 1) % QmfIntegerProp::SIZE)
  end
  
  expose :next do |args|
    args.declare :result, :objId, :out
  end

  qmf_property :int_id, :int, :index=>true

  qmf_class_name :QmfIntegerProp
  qmf_package_name :example
end


