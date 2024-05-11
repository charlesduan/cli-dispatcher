require 'rake'
require 'date'

Gem::Specification.new do |s|
    s.name = 'cli-dispatcher'
    s.version = '1.1.7'
    s.date = Date.today.to_s
    s.summary = 'Command-line command dispatcher'
    s.description = <<~EOF
        Library for creating command-line programs that accept commands. Also
        includes the Structured class for processing YAML files containing
        structured data.
    EOF
    s.author = [ 'Charles Duan' ]
    s.email = 'rubygems.org@cduan.com'
    s.files = FileList[
        'lib/**/*.rb',
        # 'test/**/*.rb',
        # 'bin/*'
    ].to_a
    s.license = 'MIT'
    s.homepage = 'https://github.com/charlesduan/cli-dispatcher'
end

