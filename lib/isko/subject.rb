module Isko
	class Subject
		def initialize(code: nil, name: nil, semester: nil,
			credits: nil, requirements: nil)
			@code, @name, @semester, @credits, @requirements =
				code, name, semester, credits, requirements
		end

		attr_reader :code, :name, :semester, :credits, :requirements
	end
end
