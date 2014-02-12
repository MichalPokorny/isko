module Isko
	class Subject
		def initialize(code: nil, name: nil, semester: nil, points: nil, credits: nil)
			@code, @name, @semester, @points, @credits = code, name, semester, points, credits
		end

		attr_reader :code, :name, :semester, :points, :credits
	end
end
