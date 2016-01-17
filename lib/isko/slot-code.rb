module Isko
	class SlotCode
		def initialize(code)
			unless match = /\A(\d{2})([ab])(.{4}\d{3})([xp])((\d+)[abcdef]*&*)\Z/.match(code)
				raise "Unknown slot code format: #{code}"
			end

			@code = code
			@year_code = match[1]
			@semester_code = match[2]
			@subject_code = match[3]
			@slot_type_code = match[4].to_sym
			@extras = match[5]
		end

		attr_reader :extras
		attr_reader :code
		attr_reader :subject_code
		attr_reader :slot_type_code

		def slot_type
			case @slot_type_code
			when :x
				:cviceni
			when :p
				:prednaska
			else
				raise "Unknown slot type code: #{type}"
			end
		end

		def prednaska?
			slot_type == :prednaska
		end

		def cviceni?
			slot_type == :cviceni
		end

		def ==(other)
			code == other.code
		end

		def to_s
			"#<Isko::SlotCode:#{object_id} #{code}>"
		end
	end
end
