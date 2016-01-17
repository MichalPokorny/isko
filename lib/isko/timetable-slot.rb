require 'isko/days'
require 'isko/time'
require 'isko/slot-code'

module Isko
	class TimetableSlot
		attr_reader :code, :teacher, :start, :place, :duration_minutes, :enrolled_students, :capacity, :students_code, :weeks

		def initialize(code: nil, teacher: nil, start: nil, place: nil,
									 duration_minutes: nil, enrolled_students: nil,
									 capacity: nil,
									 students_code: nil, weeks: nil)
			@code = SlotCode.new(code)
			@teacher, @start, @place, @duration_minutes, @enrolled_students, @students_code, @weeks, @capacity =
				teacher, start, place, duration_minutes.to_i, enrolled_students, students_code, weeks, capacity
		end

		def weird?
			start.empty?
		end

		def start_day
			Days.find(Time.parse_human(start)[:day])
		rescue
			puts "Failed to parse slot #{code} start day: '#{start}'"
			raise
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

		def week_parities
			case weeks
			when :even
				[:even]
			when :odd
				[:odd]
			when :all
				[:even, :odd]
			else raise end
		end

		def collision?(other_slot)
			common_parities = week_parities & other_slot.week_parities
			week_collision = !(common_parities.empty?)

			week_collision && start_day == other_slot.start_day && time_collision?(other_slot)
		end

		def subject_code
			@code.subject_code
		end

		def type
			@code.slot_type
		end

		def prednaska?
			@code.prednaska?
		end

		def cviceni?
			@code.cviceni?
		end

		def teacher_surnames
			self.class.teacher_surnames(teacher)
		end

		def self.teacher_surnames(teachers)
			teachers.split(",").map { |teacher| teacher.split.first }.reject { |name|
				%w{prof. Mgr. RNDr. Ph.D. DrSc. CSc.}.include? name
			}.join(", ")
		end
	end
end
