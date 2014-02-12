require 'test_helper'
require 'isko/agent'
require 'isko/null-cache'
require 'isko/subject'
require 'isko/exam-result'

module Isko
	class AgentTest < Test::Unit::TestCase
		def test_should_get_main_page
			agent = Agent.new(cache: NullCache.new)
			assert agent.main_page
		end

		def test_should_get_subject_by_code
			code = "NAIL062"
			agent = Agent.new(cache: NullCache.new)
			assert(subject = agent.get_subject_by_code(code))
			assert subject.is_a?(Subject) && subject.code == "NAIL062" && subject.name =~ /logika/
		end

		def test_should_get_slot_instances
			code = "13bNDBI025p1"
			agent = Agent.new(cache: NullCache.new)
			assert(slot = agent.all_slot_instances(code))
			assert slot.is_a?(Array) && slot.all? { |d| d.is_a? Date }
		end

		def test_should_get_exam_results
			agent = Agent.new(cache: NullCache.new)
			assert(results = agent.exam_results)
			assert results.is_a?(Array) && results.all? { |r| r.is_a? ExamResult }
		end
	end
end
