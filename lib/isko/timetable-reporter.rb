module Isko
	module TimetableReporter
		def self.report_results(agent, result, file)
			shown = result[:slots].map { |slot|
				s = {
					day: SisAgent::DAYS.index(SisAgent.slot_start_day(slot)),
					start: SisAgent.slot_absolute_start(slot),
					length: slot[:time_minutes],
					code: slot[:code],
					subject_code: SisAgent.slot_code_to_subject_code(slot[:code]),
					type: SisAgent.slot_code_to_type(slot[:code]),
					teacher: slot[:teacher],
				}
				s[:subject_name] = agent.get_subject_name(s[:subject_code])
				s
			}

			outside_slots = result[:outside_slots].reject { |slot|
				SisAgent::slot_weird?(slot)
			}.map { |slot|
				s = {
					day: SisAgent::DAYS.index(SisAgent.slot_start_day(slot)),
					start: SisAgent.slot_absolute_start(slot),
					length: slot[:time_minutes],
					code: slot[:code],
					subject_code: SisAgent.slot_code_to_subject_code(slot[:code]),
					type: SisAgent.slot_code_to_type(slot[:code]),
					teacher: slot[:teacher],
				}
				s[:subject_name] = agent.get_subject_name(s[:subject_code])
				s
			}

			subjects = result[:subjects].map { |subject|
				{
					code: subject,
					name: agent.get_subject_name(subject),
					credits: agent.get_subject_credits(subject),
					slots: shown.select { |s| s[:subject_code] == subject }
				}
			}

			eng = Haml::Engine.new(File.read('_template.html.haml'))
			File.write(file, eng.render(Object.new, {
				shown: shown,
				subjects: subjects,
				objective: result[:objective],
				outside_slots: outside_slots,
				raw_output: result[:raw_output]
			}))
		end
	end
end
