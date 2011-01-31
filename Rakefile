# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugins.delete :rubyforge
Hoe.plugin :git
Hoe.plugin :rcov

Hoe.spec 'rdbi' do
  developer 'Erik Hollensbe', 'erik@hollensbe.org'

  self.rubyforge_name = nil

  self.description = <<-EOF
  RDBI is a database interface built out of small parts. A micro framework for
  databases, RDBI works with and extends libraries like 'typelib' and 'epoxy'
  to provide type conversion and binding facilities. Via a driver/adapter
  system it provides database access. RDBI itself provides pooling and other
  enhanced database features.
  EOF

  self.summary = 'RDBI is a database interface built out of small parts.'
  self.url = %w[http://github.com/rdbi/rdbi]
  
  require_ruby_version ">= 1.8.7"

  extra_dev_deps << ['rdbi-driver-mock']
  extra_dev_deps << ['test-unit']
  extra_dev_deps << ['rdoc']
  extra_dev_deps << ['hanna-nouveau']
  extra_dev_deps << ['fastercsv']
  extra_dev_deps << ['roodi']
  extra_dev_deps << ['reek']

  extra_deps << ['epoxy', '>= 0.3.1']
  extra_deps << ['typelib']

  desc "install a gem without sudo"
  task :install => [:gem] do
    sh "gem install pkg/#{self.name}-#{self.version}.gem"
  end
end

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

begin
  require 'reek/rake/task'
  Reek::Rake::Task.new do |t|
    t.reek_opts << '-q'
  end
rescue LoadError
  task :reek do
    abort "Reek is not available. 'gem install reek'."
  end
end

# vim: syntax=ruby
