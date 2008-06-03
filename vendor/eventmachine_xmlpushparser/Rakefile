# $Id: Rakefile 3546 2006-12-31 21:01:27Z francis $
# Rakefile for the Bayshore configurable LDAP server.
#


require 'rake/gempackagetask'
require 'rake/clean'



$can_minitar = false
begin
  require 'archive/tar/minitar'
  require 'zlib'
  $can_minitar  = true
rescue LoadError
end

$version = "0.0.1"
$distdir  = "eventmachine_xmlpushparser-#{$version}"
$tardist  = "#$distdir.tar.gz"
$name = "eventmachine_xmlpushparser"


spec = eval(File.read("eventmachine_xmlpushparser.gemspec"))
spec.version = $version
desc "Build the RubyGem for EventMachine XML push-parser"
task :gem => ["pkg/eventmachine_xmlpushparser-#{$version}.gem"]
Rake::GemPackageTask.new(spec) do |g|
  if $can_minitar
    g.need_tar    = true
    g.need_zip    = true
  end
  g.package_dir = "pkg"
end


specbinary = eval(File.read("eventmachine_xmlpushparser-binary.gemspec"))
specbinary.version = $version
desc "Build a binary RubyGem for EventMachine XML push-parser"
task :gembinary => ["pkg/eventmachine_xmlpushparser-binary-#{$version}.gem"]
Rake::GemPackageTask.new(specbinary) do |g|
  if $can_minitar
    g.need_tar    = true
    g.need_zip    = true
  end
  g.package_dir = "pkg"
end



def run_test_package test, filename_array
  require 'test/unit/testsuite'
  require 'test/unit/ui/console/testrunner'

  runner = Test::Unit::UI::Console::TestRunner

  $LOAD_PATH.unshift('test')
  $stderr.puts "Checking for test cases:" if test.verbose
  filename_array.each do |testcase|
    $stderr.puts "\t#{testcase}" if test.verbose
    load testcase
  end

  suite = Test::Unit::TestSuite.new($name)

  ObjectSpace.each_object(Class) do |testcase|
    suite << testcase.suite if testcase < Test::Unit::TestCase
  end

  runner.run(suite)
end

desc "Run the tests for #$name."
task :test do |t|
    run_test_package t, Dir['test/*.rb']
end

desc "Run the application tests"
task :test_application do |t|
    run_test_package t, Dir['test/app.rb']
end

task :default => [:test]

