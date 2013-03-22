require 'helper'

puts RDBI.constants

class TestImplicitLoad < Test::Unit::TestCase

  ConnectTests = {
    # Mmmph.  It would be nice if suites were run in separate processes
    "StringHyphen" => { :found_here => 'rdbi-driver-stringhyphen',
                        :not_here   => 'rdbi/driver/stringhyphen' },
    :SymbolHyphen  => { :found_here => 'rdbi-driver-symbolhyphen',
                        :not_here   => 'rdbi/driver/symbolhyphen' },
    "StringSubdir"  => { :found_here => 'rdbi/driver/stringsubdir',
                        :not_here   => 'rdbi-driver-stringsubdir' },
    :SymbolSubdir   => { :found_here => 'rdbi/driver/symbolsubdir',
                        :not_here   => 'rdbi-driver-symbolsubdir' },
    "StringHyphenCached"  => { :found_here => 'rdbi-driver-stringhyphencached',
                               :not_here   => 'rdbi/driver/stringhyphencached' },
    :SymbolHyphenCached   => { :found_here => 'rdbi-driver-symbolhyphencached',
                               :not_here   => 'rdbi/driver/symbolhyphencached' },
    "StringSubdirCached"  => { :found_here => 'rdbi/driver/stringsubdircached',
                               :not_here   => 'rdbi-driver-stringsubdircached' },
    :SymbolSubdirCached   => { :found_here => 'rdbi/driver/symbolsubdircached',
                               :not_here   => 'rdbi-driver-symbolsubdircached' },
  }

  ConnectTests.each do |spec, feature|
    meth = 'test_implicit_' + spec.to_s.gsub(/([a-z0-9])([A-Z])/, '\1_\2').downcase
    how = (spec =~ /Cached/ ? :connect_cached : :connect)
    define_method meth.to_sym do
      assert_implicitly_loaded(how, spec, feature[:found_here], feature[:not_here])
    end
  end

  def test_01_module_loaded
    require 'rdbi/driver/mock'
    RDBI::Driver::Mock
    assert(module_loaded?('RDBI::Driver::Mock'),
           "Mock driver unexpectedly not loaded")
    assert(!module_loaded?('RDBI::Driver::FauxSQL'),
           "FauxSQL unexpectedly loaded already")
  end

  def test_02_implicit_load_fail
    assert(!module_loaded?('RDBI::Driver::NoSuchDriver'))
    assert_raises(ArgumentError) do
      RDBI.connect(:NoSuchDriver, {:username=>:a,:password=>:b})
    end
    assert(!module_loaded?('RDBI::Driver::NoSuchDriver'))
  end

  # ========== Utility =========================

  # Is the given module loaded?
  def module_loaded?(name)
    names = name.split(/::/)      # ::Foo::Bar -> ["", "Foo", "Bar"]
    names.shift if names[0] == ""
    resolved = names.inject(::Kernel) { |mod, n| mod = mod.const_get(n) }
    resolved.is_a?(::Module)
  rescue NameError => ne
    nil
  end

  # For a given feature 'f' (which was or could be an argument to
  # Kernel.require), see if it has already been loaded
  def feature_loaded?(f)
    #require 'pathname'
    #f = ::Pathname.new(f).cleanpath

    $LOADED_FEATURES.any? do |loaded|
      loaded.match('(^|/)' + Regexp.quote(f) + '\.[^/]+$')
    end
  end

  def assert_feature_loaded(f, msg = nil)
    msg ||= "Feature #{f} unexpectedly not loaded"
    assert(feature_loaded?(f), msg)
  end

  def assert_feature_not_loaded(f, msg = nil)
    msg ||= "Feature #{f} unexpectedly already loaded"
    assert(!feature_loaded?(f), msg)
  end

  def assert_module_loaded(m, msg = nil)
    msg ||= "Module #{m} unexpectedly not loaded"
    assert(module_loaded?(m), msg)
  end

  def assert_module_not_loaded(m, msg = nil)
    msg ||= "Module #{m} unexpectedly already loaded"
    assert(!module_loaded?(m), msg)
  end

  def assert_implicitly_loaded(connect_method, shortname, found_here, not_here)
    qualified_name = "RDBI::Driver::#{shortname}"

    assert_module_not_loaded(qualified_name)
    assert_feature_not_loaded(found_here)
    assert_feature_not_loaded(not_here)

    conn_args = { :username => :a, :password => :b }
    conn_args[:pool_name] = shortname.to_sym if connect_method == :connect_cached
    dbh = ::RDBI.__send__(connect_method, shortname, conn_args)
    assert_module_loaded(qualified_name)

    klass = ::RDBI::Driver.const_get(shortname)

    assert(dbh.connected?, "connect(#{shortname}) did not return connected DBH")
    assert_kind_of(klass, dbh.driver,
                   "DBH.driver was not a #{klass.name}")

    assert_feature_loaded(found_here)
    assert_feature_not_loaded(not_here)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
