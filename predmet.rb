#!/usr/bin/ruby -w

$: << '.'
require 'sis-agent'
require 'terminal-table'

agent = SisAgent.new

if ARGV.empty?
	puts "usage: predmet.rb (code1) (code2) ..."
	exit 1
end

def subject_to_table(s)
	"#{s.code.rjust 10} #{s.name.ljust 30}#{SisAgent.semester_to_human(s.semester).ljust 10}"
end

table = Terminal::Table.new do |t|
	subjects = ARGV.map do |p|
		begin
			agent.get_subject_by_code(p)
		rescue SisAgent::WrongFormat
			puts "warning: #{p}: wrong format"
	#	rescue => e
	#		puts "warning: #{p}: nejde stahnout (#{e.inspect})"
		end
	end.compact

	winter = subjects.select { |s| s.semester == :winter }
	summer = subjects.select { |s| s.semester == :summer }

	winter.each do |s|
		t << [ s.code, s.name, SisAgent.semester_to_human(s.semester), s.credits ]
	end

	unless winter.empty? || summer.empty?
		t << :separator
	end

	summer.each do |s|
		t << [ s.code, s.name, SisAgent.semester_to_human(s.semester), s.credits ]
	end
end

puts table
