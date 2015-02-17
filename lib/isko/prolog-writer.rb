require 'active_support/core_ext/string'

module Isko
	class PrologWriter
		def initialize(prolog_path)
			@prolog_path = prolog_path

			@prolog = File.open(prolog_path, "w")
			@prolog << <<-EOF.strip_heredoc
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

		protected
		attr_reader :prolog

		public
		extend Forwardable
		delegate puts: :prolog

		def execute_for_output
			@prolog.close
			FileUtils.chmod "+x", @prolog_path
			`swipl -q -g main #@prolog_path`
		end
	end
end
