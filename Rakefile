require 'rubygems'
require 'rake'

version = (File.exist?('VERSION') ? File.read('VERSION') : "").chomp

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rdbi"
    gem.summary = %Q{RDBI provides sane query-level database access with low magic.}
    gem.description = %Q{RDBI is a rearchitecture of the Ruby/DBI project by its maintainer and others. It intends to fully supplant Ruby/DBI in the future for similar database access needs.}
    gem.email = "erik@hollensbe.org"
    gem.homepage = "http://github.com/erikh/rdbi"
    gem.authors = ["Erik Hollensbe"]

    gem.add_development_dependency 'test-unit'
    gem.add_development_dependency 'rdoc'
    gem.add_development_dependency 'hanna'
    unless RUBY_VERSION =~ /^1.9/
      gem.add_development_dependency 'fastercsv'
    end
    gem.add_development_dependency 'rdbi-driver-mock'

    gem.add_dependency 'methlab', '>= 0.0.9'
    gem.add_dependency 'epoxy', '>= 0.2.1'
    gem.add_dependency 'typelib'

    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

begin
  gem 'test-unit'
  require 'rake/testtask'
  Rake::TestTask.new(:test) do |test|
    test.libs << 'lib' << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :test do
    abort "test-unit gem is not available. In order to run test-unit, you must: sudo gem install test-unit"
  end
end


begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

begin
  require 'roodi'
  require 'roodi_task'
  RoodiTask.new do |t|
    t.verbose = false
  end
rescue LoadError
  task :roodi do
    abort "Roodi is not available. In order to run roodi, you must: sudo gem install roodi"
  end
end

task :default => :test

begin
  gem 'hanna'
  require 'hanna/rdoctask'
  Hanna::Task.new do |rdoc|
    version = File.exist?('VERSION') ? File.read('VERSION') : ""

    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "rdbi #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
rescue LoadError => e
  abort "What, were you born in a barn? Install rdoc."
end

task :rdoc => [:clobber_rdoc]
 
task :to_blog => [:clobber_rdoc, :rdoc] do
  sh "rm -fr $git/blog/content/docs/rdbi && mv doc $git/blog/content/docs/rdbi"
end

task :install => [:test, :build]

task :docview => [:rerdoc] do
  sh "open rdoc/index.html"
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
