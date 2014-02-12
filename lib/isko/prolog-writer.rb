module Isko
	class PrologWriter
		def initialize(prolog_path)
			@prolog_path = prolog_path

			@prolog = File.open(prolog_path, "w")
			@prolog << <<-EOF
				:-use_module(library(clpfd)).
				main :-
			EOF
		end

		def clause(line)
			@prolog.puts "\t#{line},"
		end

		def comment(comment)
			@prolog.puts "\t% #{comment}"
		end

		def empty_line
			@prolog.puts
		end

		def close
			@prolog.close
		end

		delegate :puts, to: :prolog

		def execute_for_output
			FileUtils.chmod "+x", @prolog_path
			`swipl -q -g main #@prolog_path`
		end
	end
end
