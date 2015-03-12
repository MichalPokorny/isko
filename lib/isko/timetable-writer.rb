require 'isko/days'
require 'haml'

module Isko
	module TimetableWriter
		def self.report_results(agent, slots, file)
			engine = Haml::Engine.new(File.read('_timetable_template.html.haml'))
			File.write(file, engine.render(Object.new, agent: agent, slots: slots))
		end
	end
end
