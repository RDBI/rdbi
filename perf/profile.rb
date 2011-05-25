$:.unshift 'lib'
require 'rubygems'
require 'rdbi'
require 'fileutils'
ENV["driver"] ||= "SQLite3"
require "rdbi/driver/#{ENV["driver"].downcase}"
require 'perftools'

FileUtils.rm 'test.db' rescue nil

dbh = nil

if ENV["driver"] == "SQLite3"
  dbh = RDBI.connect(:SQLite3, :database => "test.db")
else
  require 'rdbi-dbrc'
  dbh = RDBI::DBRC.connect("#{ENV["driver"]}_test")
end

dbh.execute("drop table foo") rescue nil
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
  sth = dbh.prepare("insert into foo (i) values (?)")
  10_000.times do |x|
    sth.execute_modification(x)
  end
  sth.finish

  FileUtils.rm '/tmp/rdbi_res_select' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_res_select") do
    sth = dbh.prepare("select * from foo")
    100.times do |x|
      sth.execute.fetch(:all)
    end
    sth.finish
  end
when "single_fetch"
  dbh.execute("insert into foo (i) values (?)", 1)

  FileUtils.rm '/tmp/rdbi_single_fetch' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_single_fetch") do
    sth = dbh.prepare("select * from foo")
    10_000.times do |x|
      sth.execute.fetch(1)
    end
    sth.finish
  end
when "unprepared_raw_select"
  sth = dbh.prepare("insert into foo (i) values (?)")
  10_000.times do |x|
    sth.execute_modification(x)
  end
  sth.finish

  FileUtils.rm '/tmp/rdbi_unprepared_raw_select' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_unprepared_raw_select") do
    100.times do |x|
      dbh.execute("select * from foo").raw_fetch(:all)
    end
  end
when "unprepared_res_select"
  sth = dbh.prepare("insert into foo (i) values (?)")
  10_000.times do |x|
    sth.execute_modification(x)
  end
  sth.finish

  FileUtils.rm '/tmp/rdbi_unprepared_res_select' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_unprepared_res_select") do
    100.times do |x|
      dbh.execute("select * from foo").fetch(:all)
    end
  end
when "unprepared_single_fetch"
  dbh.execute("insert into foo (i) values (?)", 1)

  FileUtils.rm '/tmp/rdbi_unprepared_single_fetch' rescue nil
  PerfTools::CpuProfiler.start("/tmp/rdbi_unprepared_single_fetch") do
    10_000.times do |x|
      dbh.execute("select * from foo").fetch(1)
    end
  end
else
  $stderr.puts "[prepared_insert|insert|raw_select|res_select|single_fetch|unprepared_res_select|unprepared_single_fetch]"
  exit 1
end

dbh.disconnect
