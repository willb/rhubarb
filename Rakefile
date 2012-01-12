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

def name
  return 'rhubarb'
end

def pkg_name
  "ruby-#{name}"
end

def pkg_spec
  "#{pkg_name}.spec"
end

def pkg_rel
  return `grep -i 'define rel' #{pkg_spec} | awk '{print $3}'`.chomp()
end

def pkg_source
  return "#{pkg_name}-#{pkg_version}.tar.gz"
end

def pkg_dir
  return pkg_name() + "-" + pkg_version()
end

def rpm_dirs
  return %w{BUILD BUILDROOT RPMS SOURCES SPECS SRPMS}
end

def package_prefix
  "#{pkg_name}-#{pkg_version}"
end

def pristine_name
  "#{package_prefix}.tar.gz"
end

desc "upload a pristine tarball for the current release to fedorahosted"
task :upload_pristine => [:pristine] do
  raise "Please set FH_USERNAME" unless ENV['FH_USERNAME']
  sh "scp #{pristine_name} #{ENV['FH_USERNAME']}@fedorahosted.org:grid"
end

desc "generate a pristine tarball for the tag corresponding to the current version"
task :pristine do
  sh "git archive --format=tar v#{pkg_version} --prefix=#{package_prefix}/ | gzip -9nv > #{pristine_name}"
end

desc "create RPMs"
task :rpms => [:tarball, :gen_spec] do
  FileUtils.cp pkg_spec(), 'SPECS'
  sh "rpmbuild --define=\"_topdir \${PWD}\" -ba SPECS/#{pkg_spec}"
end

desc "Generate the specfile"
task :gen_spec do
  sh "cat #{pkg_spec}" + ".in" + "| sed 's/RHUBARB_VERSION/#{pkg_version}/' > #{pkg_spec}"
end

desc "Create a tarball"
task :tarball => [:make_rpmdirs, :pristine] do
  FileUtils.cp pristine_name, 'SOURCES'
end

desc "Make dirs for building RPM"
task :make_rpmdirs => :clean do
  FileUtils.mkdir pkg_dir()
  FileUtils.mkdir rpm_dirs()
end

desc "Cleanup after an RPM build"
task :clean do
  require 'fileutils'
  FileUtils.rm_r [pkg_dir(), rpm_dirs(), pkg_spec(), 'pkg', name() + ".gemspec"], :force => true
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov_opts << "-x" << "/usr/lib" << "-x" << ".gem"
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
    test.rcov_opts << "-x" << "/usr/lib" << "-x" << ".gem"
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
