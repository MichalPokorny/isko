module Isko
	class NullCache
		def contains?(*)
			false
		end

		def save_yaml(*)
			# nop
		end
	end
end
