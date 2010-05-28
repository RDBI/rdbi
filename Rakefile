require 'rubygems'
require 'rake'

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

        gem.add_dependency 'methlab', '>= 0.0.9'
        gem.add_dependency 'epoxy', '>= 0.2.1'

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

require 'rdoc/task'
RDoc::Task.new do |rdoc|
    version = File.exist?('VERSION') ? File.read('VERSION') : ""

    rdoc.rdoc_dir = 'rdoc'
    rdoc.title = "rdbi #{version}"
    rdoc.rdoc_files.include('README*')
    rdoc.rdoc_files.include('lib/**/*.rb')
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
