require 'rubygems'
require 'rake'

begin 
  require 'metric_fu'
  MetricFu::Configuration.run do |config|
    #define which metrics you want to use
    config.metrics  = [:flog, :flay, :reek, :roodi]
    config.graphs   = [:flog, :flay, :reek, :roodi]
    config.flay     = { :dirs_to_flay => ['lib'],
                          :minimum_score => 10  } 
    config.flog     = { :dirs_to_flog => ['lib']  }
    config.reek     = { :dirs_to_reek => ['lib']  }
    config.roodi    = { :dirs_to_roodi => ['lib'] }
    config.graph_engine = :bluff
  end
rescue LoadError
  nil
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rhubarb"
    gem.summary = %Q{Rhubarb:  object graph persistence, easy as pie}
    gem.description = %Q{Rhubarb is a simple object-graph persistence library implemented as a mixin.  It also works with the SPQR library for straightforward object publishing over QMF.}
    gem.email = "willb@redhat.com"
    gem.homepage = "http://git.fedorahosted.org/git/grid/rhubarb.git"
    gem.authors = ["William Benton"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_dependency "sqlite3-ruby", ">= 1.2.2"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

def pkg_version
  version = File.exist?('VERSION') ? File.read('VERSION') : ""
  return version.chomp
end

def pkg_version
  version = File.exist?('VERSION') ? File.read('VERSION') : ""
  return version.chomp
end

def pkg_name
  return 'ruby-rhubarb'
end

def pkg_spec
  return pkg_name() + ".spec"
end

def pkg_rel
  return `grep -i 'define rel' #{pkg_spec} | awk '{print $3}'`.chomp()
end

def pkg_source
  return pkg_name() + "-" + pkg_version() + "-" + pkg_rel() + ".tar.gz"
end

def pkg_dir
  return pkg_name() + "-" + pkg_version()
end

def rpm_dirs
  return %w{BUILD BUILDROOT RPMS SOURCES SPECS SRPMS}
end

desc "create RPMs"
task :rpms => [:build, :tarball] do
  require 'fileutils'
  FileUtils.cp pkg_spec(), 'SPECS'
  sh "rpmbuild --define=\"_topdir \${PWD}\" -ba SPECS/#{pkg_spec}"
end

desc "Create a tarball"
task :tarball => :make_rpmdirs do
  require 'fileutils'
  FileUtils.cp_r 'lib', pkg_dir()
  FileUtils.cp ['LICENSE', 'README.rdoc', 'CHANGES', 'TODO', 'VERSION'], pkg_dir()
  sh "tar -cf #{pkg_source} #{pkg_dir}"
  FileUtils.mv pkg_source(), 'SOURCES'
end

desc "Make dirs for building RPM"
task :make_rpmdirs => :rpm_clean do
  require 'fileutils'
  FileUtils.mkdir pkg_dir()
  FileUtils.mkdir rpm_dirs()
end

desc "Cleanup after an RPM build"
task :rpm_clean do
  require 'fileutils'
  FileUtils.rm_r pkg_dir(), :force => true
  FileUtils.rm_r rpm_dirs(), :force => true
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies


require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
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
  require 'reek/adapters/rake_task'
  Reek::RakeTask.new do |t|
    t.fail_on_error = true
    t.verbose = false
    t.source_files = 'lib/**/*.rb'
  end
rescue LoadError
  task :reek do
    abort "Reek is not available. In order to run reek, you must: sudo gem install reek"
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

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rhubarb #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
