module Isko
	module Time
		def self.absolute_minutes_to_human(minutes)
			"#{minutes / 60}:#{minutes % 60}"
		end

		def self.human_time_to_absolute_minutes(human_time)
			unless match = /\A(\d+):(\d+)\Z/.match(human_time)
				raise "Invalid time format: #{human_time}"
			end

			absolute_minutes(hour: match[1], minute: match[2])
		end

		def self.parse_human(human)
			unless match = /\A(.+) (\d+):(\d+)\Z/.match(human)
				raise "Invalid time format: #{human}"
			end

			{ day: match[1], hour: match[2], minute: match[3] }
		end

		def self.absolute_minutes(hash)
			hash[:hour].to_i * 60 + hash[:minute].to_i
		end
	end
end
