require 'rake/clean'
require "rubygems/package_task"

require "./trad-getopt.rb"	# Getopt::VERSION

task :default => :gem

task :gem
spec = Gem::Specification.new { |s|
  s.name = "trad-getopt"
  s.version = Getopt::VERSION
  s.author = "NOZAWA Hiromasa"
  s.summary = "rather traditional getopt()"
  s.license = "BSD-2-Clause"
  s.homepage = "https://github.com/noz/ruby-trad-getopt"
  s.files = FileList[
    "LICENSE",
    "Rakefile",
    "test.rb",
    "trad-getopt.rb",
    "trad-getopt.txt",
  ]
  s.require_path = "."
}
Gem::PackageTask.new(spec) { |pkg|
  pkg.need_tar_gz = true
  pkg.need_tar_bz2 = true
  pkg.need_zip = true
}

# require "rake/testtask"
# Rake::TestTask.new { |t|
#   t.test_files = FileList["test.rb"]
# }
desc "do unit test"
task :test {
  ruby "-w", "test.rb"
}
