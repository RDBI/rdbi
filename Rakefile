require 'rake/testtask'
require 'rubygems/package_task'

require File.expand_path('../lib/rdbi/version', __FILE__)

Rake::TestTask.new do |t|
  t.libs << 'test'
  #t.warning = true
  t.verbose = true
end

Gem::PackageTask.new(eval(File.read("rdbi.gemspec"))) do
end

task :default => :test
