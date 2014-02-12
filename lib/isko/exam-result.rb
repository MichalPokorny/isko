module Isko
	class ExamResult
		attr_reader :code, :result

		def initialize(code: nil, result: nil)
			@code, @result = code, result
		end
	end
end
