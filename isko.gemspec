Gem::Specification.new do |s|
	s.name = "isko"
	s.version = "0.0.1"
	s.date = "2014-02-12"
	s.summary = "Charles University information system robot"
	s.description = "A toolbox for automatically accessing some functions of Charles University information system"
	s.authors = ["Michal Pokorný"]
	s.email = "pok@rny.cz"
	s.files = Dir["lib/**/*.rb", "lib/*"]
	s.license = "GPL 3.0"

	s.runtime_dependency 'yaml'
	s.runtime_dependency 'mechanize'
	s.runtime_dependency 'terminal-table'
	s.runtime_dependency 'haml'
end
