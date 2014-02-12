module Isko
	module Days
		DAYS = %w{Po Út St Čt Pá}.freeze

		def self.find(name)
			raise "Unknown day: #{name}" unless DAYS.include?(name)
			DAYS.index(name)
		end

		def self.index?(i)
			DAYS[i]
		end

		def self.[](i)
			raise "Unknown day index: #{i}" unless index?(i)
			DAYS[i]
		end

		def self.each(&block)
			DAYS.each(&block)
		end

		def self.each_index(&block)
			DAYS.each_index(&block)
		end
	end
end
