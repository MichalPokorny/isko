require 'isko/days'
require 'isko/time'
require 'isko/prolog-writer'

module Isko
	class PrologGen
		attr_accessor :forbid_teachers
		def initialize(prolog_path, agent)
			@slots_by_code = {}

			@forbid_teachers = []

			@choose_subject_vars = {}
			@choose_slots_vars = {}

			@all_slots = []
			@agent = agent

			@prolog_writer = PrologWriter.new(prolog_path)
		end

		delegate :clause, to: :prolog_writer
		delegate :comment, to: :prolog_writer
		delegate :empty_line, to: :prolog_writer

		public
		def all_vars
			@choose_subject_vars.values + @choose_slots_vars.values
		end

		def choose_slot_var(slot)
			@choose_slots_vars[slot.code]
		end

		def add_slots(slots)
			@all_slots += slots
			slots.each do |s|
				@slots_by_code[s.code] = s
			end
		end

		def dont_want_insane_hours(hours_proc, value)
			comment "Don't want insane hours (#{value} pts)"
			bad = []
			@all_slots.each do |slot|
				next if slot.weird?
				if hours_proc.call(slot.absolute_end_in_minutes) || hours_proc.call(slot.absolute_start_in_minutes)
					bad << choose_slot_var(slot)
				end
			end

			unless bad.empty?
				clause "#{new_reward_var} #= #{-value} * (#{bad.join(' + ')})"
			else
				comment "(No insane hours anywhere.)"
			end
		end

		def want_to_do_nothing(value)
			v = new_reward_var
			comment "Don't want to work (#{value} pts)"
			clause "#{v} #= - #{value} * (#{@choose_slots_vars.values.join(' + ')})"
		end

		# TODO: proc to bylo potreba???
		#def uniquize_slot_codes(slots)
		#	s = []
		#	slots.each do |slot|
		#		code = slot.code
		#		code << '*' while s.map(&:code).include? code
		#		s << slot.merge(code: code)
		#	end
		#	s
		#end

		def add_subject(code)
			subject = @agent.get_subject_by_code(code)
			comment "#{code} #{subject.name}, #{subject.credits} kr"
			sv = "TAKE_#{code}"
			@choose_subject_vars[code] = sv
			clause "#{sv} in 0 \\/ 1"

			slots = @agent.get_subject_timetable_slots(code)

			#slots = uniquize_slot_codes(slots)

			add_slots(slots)

			prednasky = slots.select(&:prednaska?)
			cviceni = slots.select(&:cviceni?)

			unless (prednasky + cviceni).size == slots.size
				pp slots
				pp prednasky
				pp cviceni
				raise "jsou i nejake sloty jine nez prednasky a cvika"
			end

			raise "neunikatni kody slotu: #{slots.inspect}" unless slots.map(&:code).uniq.size == slots.size

			unless prednasky.empty?
				var_prednaska = "#{code}_PREDNASKA"
				clause "#{var_prednaska} in 0..#{prednasky.count}"
				# 0 == "nevybiram si nic"
				clause "(#{var_prednaska} #= 0) #<==> (#\\ #{sv})"

				prednaskove_sloty = []
				prednasky.each.with_index do |slot, i|
					var = "#{code}_PREDNASKA_#{i}"
					comment "#{slot.start}, #{slot.duration_minutes} min"
					clause "#{var} in 0 \\/ 1"
					clause "(#{var_prednaska} #= #{i + 1}) #<==> #{var}"
					raise "dvojity slot: #{slot.code}" if choose_slots_vars.key?(slot.code)
					@choose_slots_vars[slot.code] = var
					prednaskove_sloty << var
				end

				clause "(#{sv}) #<==> (#{prednaskove_sloty.join(" #\\/ ")})"
			end

			unless cviceni.empty?
				var_cviko = "#{code}_CVICENI"
				clause "#{var_cviko} in 0..#{cviceni.count}"
				# 0 == "nevybiram si nic"
				clause "(#{var_cviko} #= 0) #<==> (#\\ #{sv})"

				cvikove_sloty = []
				cviceni.each.with_index do |slot, i|
					var = "#{code}_CV_#{i}"
					comment "#{slot.start}, #{slot.duration_minutes} min"
					clause "#{var} in 0 \\/ 1"
					clause "(#{var_cviko} #= #{i + 1}) #<==> #{var}"
					raise if @choose_slots_vars.key?(slot.code)
					@choose_slots_vars[slot.code] = var
					cvikove_sloty << var
				end

				clause "(#{sv}) #<==> (#{cvikove_sloty.join(' #\\/ ')})"
			end

			weird_slots = slots.select(&:weird?)
			unless weird_slots.empty?
				comment "Disable weird slots."
				# TODO factor out
				weird_slots.each { |slot|
					comment "Weird slot, not allowing it."
					clause "#{choose_slot_var(slot)} #= 0"
				}

				if weird_slots.size == prednasky.size + cviceni.size
					puts "WARN: #{code} has just weird slots, it won't fly"
					return
				end
			end

			slots.each do |p|
				if @forbid_teachers.include?(p.teacher)
					comment "Forbidden teacher: #{p.teacher}"
					clause "#{choose_slot_var(p)} #= 0"
				end
			end

			empty_line
		end

		def add_subjects(subjects)
			subjects.each do |p|
				add_subject(p)
			end
		end

		def add_disallowed_slot(day, start, e)
			comment "Disallowed slot"

			slots = @all_slots.select { |slot| !slot.weird? && slot.start_day == day }
			slots_in = slots.select { |s| s.pure_time_collision?(start, e) }
			slots_in.each do |s|
				clause "(#{choose_slot_var(s)} #= 0)"
			end
		end

		private
		def add_collisions
			empty_line
			comment "Collisions of slots"
			comment "(By time slots)"
			Days.each do |day|
				comment "Collisions on #{day}"
				slots = @all_slots.select { |slot| !slot.weird? && slot.start_day == day }
				times = (slots.map(&:absolute_start_in_minutes) + slots.map(&:absolute_end_in_minutes)).sort.uniq

				times.each_index do |i|
					next if i == 0
					slots_in = slots.select { |s| s.pure_time_collision?(times[i - 1], times[i]) }

					next if slots_in.length < 2
					comment "Collisions #{Time.absolute_minutes_to_human(times[i - 1])} - #{Time.absolute_minutes_to_human(times[i])}"
					clause "(#{slots_in.map { |s| choose_slots_var(s) }.join(' + ')}) #=< 1"
				end
			end

			comment "(By explicit listing)"
			@all_slots.each do |slot|
				next if slot.weird?
				collisions = []
				@all_slots.each do |slot2|
					next if slot == slot2 || slot2.weird?
					if slot.collision?(slot2)
						collisions << choose_slots_var(slot2)
					end
				end

				next if collisions.empty?

				clause "#{choose_slots_var(slot)} #==> (#{collisions.map { |c| "(#\\ #{c})" }.join(" #/\\ ")})"
			end

			empty_line
		end

		public
		def require_subjects(subjects)
			comment "Conditions on required subjects"
			subjects.each do |p|
				clause "#{@choose_subject_vars[p]} #= 1"
			end
		end

		def new_reward_var
			var = "ADDITIONAL_REWARD_#{(@additional_rewards ||= []).count}"
			@additional_rewards << var
			var
		end

		private
		def get_subject_name(code)
			@agent.get_subject_by_code(code).name
		end

		public
		def want_subjects(subjects, points)
			return if subjects.empty?
			comment "#{points} pts per each of those subjects"
			comment "(#{subjects.map { |s| get_subject_name(s) }.join(', ')})"
			clause "#{new_reward_var} #= (#{subjects.map { |s| @choose_subject_vars[s] }.join(' + ')}) * #{points}"
		end

		def require_credits(credits, subjects)
			comment "At least #{credits} credits from subjects #{subjects.join(', ')}"
			clause "(#{subjects.map { |s| "(#{@choose_subject_vars[s]} * #{@agent.get_subject_credits(s)})" }.join(' + ')}) #>= #{credits}"
		end

		def want_subjects_by_credits(subjects, mult = 1)
			comment "Those subjects are scored by their credit count"
			clause "#{new_reward_var} #= #{mult} * (#{subjects.map { |s| "(#{@choose_subject_vars[s]} * #{@agent.get_subject_credits(s)})" }.join(' + ')})"
		end

		def new_free_var
			@free_var ||= 0
			@free_var += 1
			"VAR#@free_var"
		end

		def want_subjects_by_credits_up_to(subjects, max, factor)
			comment "Those subjects are scored by their credit count up to #{max}"
			var = new_free_var
			clause "#{var} #= (#{subjects.map { |s| "(#{@choose_subject_vars[s]} * #{@agent.get_subject_credits(s)})" }.join(' + ')})"
			var2 = new_reward_var
			clause "(#{var} #> #{max}) #==> (#{var2} #= #{max * factor})"
			clause "(#{var} #=< #{max}) #==> (#{var2} #= #{var} * #{factor})"
		end

		def want_free_days(points)
			comment "Total bonus for free days (#{points} pts each)"
			clause "FREE_DAYS_TOTAL #= (#{Days.each_index.map { |i| "FREE_DAY_#{i}" }.join(' + ')})"
			clause "#{new_reward_var} #= FREE_DAYS_TOTAL * #{points}"
		end

		def require_free_day(i)
			raise unless Days.index?(i)
			comment "Required free #{Days[i]}"
			clause "FREE_DAY_#{i} #= 1"
		end

		def require_at_least_subjects(subjects, n)
			comment "At least #{n} of the following"
			raise if subjects.count < n
			clause "(#{subjects.map { |s| @choose_subject_vars[s] }.join(' + ')}) #>= #{n}"
		end

		def must_pair(subjects)
			comment "Those must go together"
			subjects.each_index do |i|
				next if i == 0
				clause "#{@choose_subject_vars[subjects[i - 1]] or raise} #<==> #{@choose_subject_vars[subjects[i]] or raise}"
			end
		end

		def prolog_close
			empty_line
			@prolog_writer.puts "\tlabeling([ffc,bisect,max(OBJECTIVE)], [#{all_vars.join(', ')}]),"

			vars = all_vars.dup
			vars += %w{OBJECTIVE}
			vars += %w{FREE_DAY_0 FREE_DAY_1 FREE_DAY_2 FREE_DAY_3 FREE_DAY_4}
			vars.map { |var|
				@prolog_writer.puts "\t\twrite('#{var}\\t'), write(#{var}), write('\\n'),"
			}
			@prolog_writer.puts "\t\twrite('\\n'),"
			@prolog_writer.puts "halt."

			@prolog_writer.close
		end

		def add_derived
			# Calculate free days
			Days.each.with_index do |day, i|
				comment "Free #{day}"
				clause "FREE_DAY_#{i} in 0 \\/ 1"
				slots = @all_slots.select { |slot| slot.start_day == day }
				code = if slots.empty?
					"1"
				else
					slots.map { |slot| "(#\\ #{choose_slots_var(slot)})" }.join(" #/\\ ")
				end
				clause "FREE_DAY_#{i} #<==> (#{code})"
			end
		end

		def add_scoring
			empty_line
			comment "Rewards"
			clause "REWARD_TOTAL #= #{(@additional_rewards || [0]).join(' + ')}"
			clause "OBJECTIVE #= REWARD_TOTAL"
		end

		def hash_reverse(hash)
			Hash[hash.map { |k, v| [v, k] }]
		end

		def execute
			@subjects_by_vars = hash_reverse(@choose_subject_vars)
			@slots_by_vars = hash_reverse(@choose_slots_vars)

			output = @prolog_writer.execute_for_output

			take_subjects = []
			take_slots = []

			objective = 0

			free_days = []

			output.each_line do |l|
				next if l.strip!.empty?
				var, value = l.split("\t")
				value = value.to_i

				if @subjects_by_vars.key?(var)
					take_subjects << @subjects_by_vars[var] if value == 1
				elsif @slots_by_vars.key?(var)
					take_slots << @slots_by_code[@slots_by_vars[var]] if value == 1
				elsif var == "OBJECTIVE"
					objective = value
				elsif var =~ /FREE_DAY_(\d+)/
					free_days << Days[$1.to_i] if value == 1
				else
					puts "!!! #{var} = #{value}"
				end
			end

			outside_slots = @all_slots.select { |slot|
				(!slot.weird?) &&
				(!take_subjects.include?(slot.subject_code)) &&
				(take_slots.none? { |b| slot.collision?(b) })
			}
			{
				subjects: take_subjects, slots: take_slots,
				objective: objective, free_days: free_days,
				outside_slots: outside_slots,
				raw_output: output
			}
		end

		def either(list)
			empty_line
			comment "Either constrain"
			clause "#{list.map { |l| "(" + (l.map { |v| @choose_subject_vars[v] or raise }.join(" #/\\ ")) + ")" }.join(" #\\/ ")}"
		end

		# Shortcut
		def finish_and_execute
			add_collisions
			add_derived
			add_scoring
			prolog_close
			execute
		end
	end
end
