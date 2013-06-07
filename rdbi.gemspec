require 'rake' # FileList
require File.expand_path('../lib/rdbi/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = %q{rdbi}
  s.version     = RDBI::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mike Pomraning", "Erik Hollensbe"]
  s.date        = %q{2013-06-05}
  s.homepage    = %q{http://github.com/RDBI/rdbi}
  s.summary     = "A ruby database abstraction layer"
  s.description = %q{RDBI is a rearchitecture of the Ruby/DBI project by its maintainer and others. It intends to fully supplant Ruby/DBI in the future for similar database access needs.}
  s.email       = ["mjp@pilcrow.madison.wi.us"]

  s.required_rubygems_version = ">= 1.3.6"

  s.require_paths = ["lib"]

  s.files            = FileList["{lib,docs,perf,test}/**/*.*",
                                "rdbi.gemspec",
                                "History.txt",
                                "Manifest.txt",
                                "Rakefile",
                                "LICENSE"].to_a
  s.test_files       = FileList["test/**/*.*"].to_a
  s.extra_rdoc_files = [ "LICENSE", "README.txt" ]

  s.add_development_dependency(%q<rdbi-driver-mock>, [">= 0"])
  s.add_development_dependency(%q<test-unit>, [">= 0"])
  s.add_development_dependency(%q<rdoc>, [">= 0"])
  s.add_runtime_dependency(%q<epoxy>, [">= 0.3.1"])
  s.add_runtime_dependency(%q<typelib>, [">= 0"])
end

