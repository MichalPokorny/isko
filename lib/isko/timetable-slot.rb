require 'isko/days'
require 'isko/time'

module Isko
	class TimetableSlot
		attr_reader :code, :teacher, :start, :place, :duration_minutes, :enrolled_students, :students_code

		def initialize(code: nil, teacher: nil, start: nil, place: nil, duration_minutes: nil, enrolled_students: nil, students_code: nil)
			@code, @teacher, @start, @place, @duration_minutes, @enrolled_students, @students_code =
				code, teacher, start, place, duration_minutes.to_i, enrolled_students, students_code
		end

		def self.parse_slot_code(code)
			unless match = /\A(\d{2})([ab])(.{4}\d{3})([xp])((\d+)[abcdef]*&*)\Z/.match(code)
				raise "Unknown slot code format: #{code}"
			end

			{
				year_code: match[1], semester_code: match[2], subject_code: match[3], slot_type_code: match[4].to_sym, extras: match[5]
			}
		end

		def self.slot_code_to_subject_code(code)
			parse_slot_code(code)[:subject_code]
		end

		def self.slot_code_to_type(code)
			type = parse_slot_code(code)[:slot_type_code]
			{ x: :cviceni, p: :prednaska }[type] or raise "Unknown slot type code: #{type}"
		end

		def weird?
			start.empty?
		end

		def start_day
			Days.find(Time.parse_human(start)[:day])
		end

		def absolute_start_in_minutes
			Time.absolute_minutes(Time.parse_human(start))
		end

		def absolute_end_in_minutes
			absolute_start_in_minutes + duration_minutes
		end

		def pure_time_collision?(other_start, other_end)
			! ((absolute_end_in_minutes <= other_start) || (other_end <= absolute_start_in_minutes))
		end

		def time_collision?(other_slot)
			! ((absolute_end_in_minutes <= other_slot.absolute_start_in_minutes) || (other_slot.absolute_end_in_minutes <= absolute_start_in_minutes))
		end

		def collision?(other_slot)
			start_day == other_slot.start_day && time_collision?(other_slot)
		end

		def subject_code
			self.class.slot_code_to_subject_code(code)
		end

		def type
			self.class.slot_code_to_type(code)
		end

		def prednaska?
			self.class.parse_slot_code(code)[:slot_type_code] == :p
		end

		def cviceni?
			self.class.parse_slot_code(code)[:slot_type_code] == :x
		end
	end
end
