require 'isko/agent'
require 'terminal-table'

module Isko
	module PrettyPrinter
		module Subjects
			def self.pretty_print(subject_codes)
				agent = Isko::Agent.new

				table = Terminal::Table.new do |t|
					subjects = subject_codes.map do |p|
						begin
							agent.get_subject_by_code(p)
						rescue Isko::Agent::WrongFormat => e
							puts "warning: #{p}: wrong format (#{e.message})"
							#	rescue => e
							#		puts "warning: #{p}: nejde stahnout (#{e.inspect})"
						end
					end.compact

					winter = subjects.select { |s| s.semester == :winter }
					summer = subjects.select { |s| s.semester == :summer }

					winter.each do |s|
						t << subject_to_table(s)
					end

					unless winter.empty? || summer.empty?
						t << :separator
					end

					summer.each do |s|
						t << subject_to_table(s)
					end
				end

				puts table
			end

			def self.subject_to_table(s)
				[
					s.code, s.name, Semester.to_human(s.semester),
					s.credits, s.requirements
				]
			end
		end
	end
end
