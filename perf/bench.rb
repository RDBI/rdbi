require 'rubygems'
require 'benchmark'
require 'sequel'
require 'rdbi'
require 'rdbi/driver/sqlite3'
gem 'activerecord', '= 2.3.8'
require 'active_record'
require 'fileutils'

include FileUtils

%w[rdbi-test.db sequel-test.db ar-test.db].each do |db|
  rm db rescue nil

  dbh = RDBI.connect(:SQLite3, :database => db)
  dbh.execute("create table foo (i integer)")
  10_000.times do |x|
    dbh.execute("insert into foo (i) values (?i)", { :i => x })
  end
  dbh.disconnect
end

dbh = RDBI.connect(:SQLite3, :database => "rdbi-test.db")
dbh.rewindable_result = false
sql = "select * from foo limit 1"
db = Sequel.connect('sqlite://sequel-test.db')
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "ar-test.db")
class Foo < ActiveRecord::Base
  set_table_name "foo"
end

puts "Single select"

n = 10_000

Benchmark.bm do |x|
  x.report("AR") { n.times { Foo.find_by_sql(sql) } }
  x.report("AR connection") { n.times { ActiveRecord::Base.connection.select_one(sql, :cache => false) } }
  x.report("RDBI") { n.times { dbh.execute(sql).first } }
  x.report("Sequel") { n.times { db[sql].first } }
end

puts "Big select"

sql = "select * from foo"

n = 50

Benchmark.bm do |x|
  x.report("AR") { n.times { Foo.find_by_sql(sql) } }
  x.report("AR connection") { n.times { ActiveRecord::Base.connection.select_all(sql, :cache => false) } }
  x.report("RDBI") { n.times { dbh.execute(sql).fetch(:all) } }
  x.report("Sequel") { n.times { db[sql].all } }
end

dbh.disconnect
db.disconnect
# wtf does AR use to disconnect anyhow
