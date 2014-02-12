module Isko
	module Days
		DAYS = %w{Po Út St Čt Pá}.freeze

		def self.find(name)
			raise "Unknown day: #{name}" unless DAYS.include(name)
			DAYS.index(name)
		end

		def self.index?(i)
			DAYS[i]
		end

		def self.[](i)
			raise "Unknown day index: #{i}" unless index?(i)
			DAYS[i]
		end

		def self.each
			DAYS.each
		end

		def self.each_index
			DAYS.each_index
		end
	end
end
