require 'isko/days'
require 'haml'

module Isko
	module TimetableWriter
		def self.report_results(agent, slots, file)
			engine = Haml::Engine.new(File.read('_timetable_template.html.haml'))
			File.write(file, engine.render(Object.new, agent: agent, slots: slots))
		end

		def self.report_results_parallel(agent, slots, file)
			day_rows = [[], [], [], [], []]

			# Very suboptimal and hungry
			for slot in slots
				day = slot.start_day
				rows_of_day = day_rows[day]

				inserted = false
				for row in rows_of_day
					if row.none? { |other| other.collision?(slot) }
						row << slot
						inserted = true
						break
					end
				end

				rows_of_day << [slot] unless inserted
			end

			engine = Haml::Engine.new(File.read('_timetable_parallel.html.haml'))
			File.write(file, engine.render(Object.new, agent: agent, day_rows: day_rows))
		end
	end
end
