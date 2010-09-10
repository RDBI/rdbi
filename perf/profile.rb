$:.unshift 'lib'
require 'rubygems'
require 'rdbi'
require 'fileutils'
gem 'rdbi-driver-sqlite3'
require 'rdbi/driver/sqlite3'
gem 'perftools.rb'
require 'perftools'

FileUtils.rm 'test.db' rescue nil

dbh = RDBI.connect(:SQLite3, :database => "test.db")

dbh.execute("create table foo (i integer)")

case ARGV[0]
when "prepared_insert"
  FileUtils.rm '/tmp/rdbi_prepared_insert' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_prepared_insert") do
    sth = dbh.prepare("insert into foo (i) values (?)")
    10_000.times do |x|
      sth.execute_modification(x)
    end
    sth.finish
  end
when "insert"
  FileUtils.rm '/tmp/rdbi_unprepared_insert' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_unprepared_insert") do
    10_000.times do |x|
      dbh.execute_modification("insert into foo (i) values (?)")
    end
  end
when "raw_select"
  sth = dbh.prepare("insert into foo (i) values (?)")
  10_000.times do |x|
    sth.execute_modification(x)
  end
  sth.finish

  FileUtils.rm '/tmp/rdbi_raw_select' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_raw_select") do
    sth = dbh.prepare("select * from foo")
    100.times do |x|
      sth.execute.raw_fetch(:all)
    end
    sth.finish
  end
when "res_select"
else
  $stderr.puts "[prepared_insert|insert|raw_select|res_select]"
  exit 1
end

dbh.disconnect
