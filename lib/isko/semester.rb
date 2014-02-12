module Isko
	module Semester
		def self.from_human(name)
			case name
			when "letní" then :summer
			when "zimní" then :winter
			when "oba" then :both
			else raise WrongFormat, "unknown semestr #{name}"
			end
		end

		def self.to_human(semester)
			case semester
			when :summer then "letní"
			when :winter then "zimní"
			else raise WrongFormat
			end
		end
	end
end
