#!/usr/bin/ruby -w

$: << '.'
require 'sis-agent'
require 'prolog-gen'
require 'haml'

require 'fileutils'
FileUtils.mkdir_p('outputs')

VOLITELNE = [ # Zajimave predmety
	# ...
]
POVINNE_VOLITELNE_MGR = [ # Predmety, co jsou volitelne na magistru
	# ...
]
POVINNE_VOLITELNE = [
	# ...
]
JAZYKY = [
	# ...
]
POVINNE = [
	'NAIL062', # vyrokovka - vyrokova a predikatova logika
	'NMAI059', # past
	'NTIN061', # ADS 2
	'NTVY016', # TV
]
VSECHNY = VOLITELNE + POVINNE_VOLITELNE_MGR + POVINNE_VOLITELNE + JAZYKY + POVINNE

@agent = SisAgent.new

def make_generator(prolog_path, bare: false)
	gen = PrologGen.new(prolog_path, @agent)

	# zakazani ucitele
	#gen.forbid_teachers = [ 'Strasny Ucitel' ]

	VSECHNY.each do |p|
		gen.add_subject(p)
	end
	gen.add_collisions

	gen.require_subjects(POVINNE) # Musim mit povinne predmety.
	gen.require_at_least_subjects(JAZYKY, 1) # Potrebuju aspon 1 jazyk.

	unless bare
		gen.require_credits(13, POVINNE_VOLITELNE) # Potrebuju nasbirat 25 z povinne volitelnych, takze na tenhle semestr 13.
		gen.require_credits(40, VSECHNY) # Potrebuju aspon 40 kreditu.
	end

	gen.either(
		[
			# A) NDMI084 + NDMI009.
			%w{NDMI009 NDMI084},
			# B) NDMI012 + NAIL063 (temno v lete).
			%w{NDMI012},
			# C) Lingvistika: NPFL012 + NPFL063. Chci je obe najednou, kdyz uz.
			%w{NPFL012 NPFL063}
		]
	)
	gen
end

def build_sane_for_credits(n_build_credits)
	# TODO: tempfile
	prolog_path = "./code.prolog"

	puts "build for credits: #{n_build_credits}"

	gen = make_generator(prolog_path, bare: true)

	# TODO: optimalizace podle poctu kreditu je asi rozbita.

	gen.want_subjects_by_credits_up_to(POVINNE_VOLITELNE, 25, 2) # Z povinne volitelnych jsou mi kredity nad 25 na nic.
	gen.want_subjects_by_credits(POVINNE_VOLITELNE_MGR, 1) # Predmety z magistra ohodnotim poctem jejich kreditu.
	gen.want_subjects_by_credits(%w{NSWI036}, -2) # Tyhle nechci.
	gen.want_free_days(1000) # Ohodnot kazdy volny den.
	gen.want_to_do_nothing(5) # Odeber za kazdy slot.

	# Odeber dalsi body za sloty v tehle casech.
	gen.dont_want_insane_hours(-> hour { hour < 9 * 60 || hour > 17 * 60 }, 1)

	# Dej za predmety X bodu navic:
	#		gen.want_subjects(POVINNE_VOLITELNE_MGR, 2)
	
	gen.require_credits(n_build_credits, VSECHNY)

	# Kdyz v tomhle semestru dostanu z bakalarskych predmetu vic nez 56 kreditu,
	# je to vlastne zbytecne.
	gen.want_subjects_by_credits_up_to(VOLITELNE + POVINNE_VOLITELNE + JAZYKY + POVINNE, 56, 1)

	#gen.require_subjects(%w{NAIL004 NAIL069}) # Chci umelou inteligenci a SUI
	#gen.require_subjects(%w{NPFL012 NPFL063}) # Chci lingvistiky

	#gen.want_subjects(%w{NAIL004 NAIL069}, 3) # Tyhle predmety chci (UI a SUI)
	gen.want_subjects(%w{NSWI090}, -1) # Tyhle predmety nechci. (to jsou Site 1) ( + NTIN018 NAIL021 NAIL076)

	# TODO: optimalizovat na kompaktnost rozvrhu
	# TODO: optimalizovat na cviciciho

	gen.add_scoring
	gen.prolog_close

	puts "Solving (credits >= #{n_build_credits})."
	result = gen.execute

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	result
end

def build_max_credits
	prolog_path = "./code.prolog"
	gen = make_generator(prolog_path)
	gen.want_subjects_by_credits_up_to(POVINNE_VOLITELNE, 25, 10000) # Z povinne volitelnych jsou mi kredity nad 25 na nic. Tyhle jsou nejdulezitejsi.
	gen.want_subjects_by_credits(POVINNE_VOLITELNE_MGR, 100) # Predmety z magistra ohodnotim poctem jejich kreditu. Pak se hodi tyhle.
	gen.want_subjects_by_credits(VOLITELNE + POVINNE_VOLITELNE + JAZYKY, 1) # Pak ostatni.
	gen.add_scoring
	gen.prolog_close

	puts "Solving (max-credits)."
	result = gen.execute

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	result
end

def build_min_hours
	prolog_path = "./code.prolog"
	gen = make_generator(prolog_path, bare: true)
	gen.want_to_do_nothing(3)
	gen.want_free_days(30)
	gen.add_scoring
	gen.prolog_close

	puts "Solving (min-hours)."
	result = gen.execute

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	result
end

def build_max_credits_plain
	prolog_path = "./code.prolog"
	gen = make_generator(prolog_path, bare: true)
	gen.want_subjects_by_credits(VSECHNY)
	gen.add_scoring
	gen.prolog_close

	puts "Solving (max-credit)."
	result = gen.execute

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	result
end

def build_mine()
	# TODO: tempfile
	prolog_path = "./code.prolog"

	puts "building the timetable"

	gen = make_generator(prolog_path, bare: true)

	# TODO: optimalizace podle poctu kreditu je asi rozbita.

	gen.want_subjects_by_credits_up_to(POVINNE_VOLITELNE, 25, 2) # Z povinne volitelnych jsou mi kredity nad 25 na nic.
	gen.want_subjects_by_credits(POVINNE_VOLITELNE_MGR, 1) # Predmety z magistra ohodnotim poctem jejich kreditu.
	gen.want_subjects_by_credits(%w{NSWI036}, -2) # Tyhle nechci.
	gen.want_free_days(1000) # Ohodnot kazdy volny den.
	gen.want_to_do_nothing(5) # Odeber za kazdy slot.

	# Odeber dalsi body za sloty v tehle casech.
	gen.dont_want_insane_hours(-> hour { hour < 9 * 60 || hour > 17 * 60 }, 1)

	# Dej za predmety X bodu navic:
	#		gen.want_subjects(POVINNE_VOLITELNE_MGR, 2)
	
	# Kdyz v tomhle semestru dostanu z bakalarskych predmetu vic nez 56 kreditu,
	# je to vlastne zbytecne.
	gen.want_subjects_by_credits_up_to(VOLITELNE + POVINNE_VOLITELNE + JAZYKY + POVINNE, 56, 1)

	gen.want_subjects(%w{NSWI090}, -1) # Tyhle predmety nechci. (to jsou Site 1) ( + NTIN018 NAIL021 NAIL076)

	# TODO: optimalizovat na kompaktnost rozvrhu
	# TODO: optimalizovat na cviciciho
	
	#gen.require_subjects(%w{NAIL004 NAIL069 NDMI012 NPRG041})
	#gen.require_subjects(%w{NDMI009 NDMI084})
	gen.require_subjects(%w{NDMI009})

	gen.add_scoring
	gen.prolog_close

	puts "Solving."
	result = gen.execute

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	result
end


def report_results(result, file)
	shown = result[:slots].map { |slot|
		s = {
			day: SisAgent::DAYS.index(SisAgent.slot_start_day(slot)),
			start: SisAgent.slot_absolute_start(slot),
			length: slot[:time_minutes],
			code: slot[:code],
			subject_code: SisAgent.slot_code_to_subject_code(slot[:code]),
			type: SisAgent.slot_code_to_type(slot[:code]),
			teacher: slot[:teacher],
		}
		s[:subject_name] = @agent.get_subject_name(s[:subject_code])
		s
	}

	outside_slots = result[:outside_slots].reject { |slot|
		SisAgent::slot_weird?(slot)
	}.map { |slot|
		s = {
			day: SisAgent::DAYS.index(SisAgent.slot_start_day(slot)),
			start: SisAgent.slot_absolute_start(slot),
			length: slot[:time_minutes],
			code: slot[:code],
			subject_code: SisAgent.slot_code_to_subject_code(slot[:code]),
			type: SisAgent.slot_code_to_type(slot[:code]),
			teacher: slot[:teacher],
		}
		s[:subject_name] = @agent.get_subject_name(s[:subject_code])
		s
	}

	subjects = result[:subjects].map { |subject|
		{
			code: subject,
			name: @agent.get_subject_name(subject),
			credits: @agent.get_subject_credits(subject),
			slots: shown.select { |s| s[:subject_code] == subject }
		}
	}

	eng = Haml::Engine.new(File.read('_template.html.haml'))
	File.write(file, eng.render(Object.new, {
		shown: shown,
		subjects: subjects,
		objective: result[:objective],
		outside_slots: outside_slots,
		raw_output: result[:raw_output]
	}))
end

#n_build_credits = 20
#until n_build_credits >= 80
#	result = build_sane_for_credits(n_build_credits)
#	unless result
#		puts "Fail."
#		break
#	end
#
#	n_build_credits = result[:subjects].map { |s| @agent.get_subject_credits(s) }.inject(&:+)
#
#	report_results(result, "outputs/output_#{n_build_credits}.html")
#
#	n_build_credits += 1
#end

VSECHNY = %w{NTIN061 NMAI059 NPRG013 NDMI012 NAIL062 NSWI090 NTVY016 NMAI062}
	prolog_path = "./code.prolog"
	gen = PrologGen.new(prolog_path, @agent)
	VSECHNY.each do |p|
		gen.add_subject(p)
	end
# Nechci tenhle cas
	gen.add_disallowed_slot("Po", 9*60 + 0, 10*60 + 30)
	gen.add_collisions
	gen.require_subjects(VSECHNY)
	gen.want_free_days(1000) # Ohodnot kazdy volny den.
	gen.want_to_do_nothing(5) # Odeber za kazdy slot.

	# Odeber dalsi body za sloty v tehle casech.
	gen.dont_want_insane_hours(-> hour { hour < 9 * 60 || hour > 17 * 60 }, 1)
	gen.add_scoring
	gen.prolog_close

	puts "Solving."
	#puts "Solving (credits >= #{n_build_credits})."
	result = gen.execute
	p result

	if result[:slots].empty?
		puts "Probably failed :("
		return nil
	end

	report_results(result, "outputs/output.html")
#result = build_sane_for_credits(40)

#result = build_max_credits
#report_results(result, "outputs/output_max_credits.html")

#result = build_mine
#report_results(result, "outputs/output.html")

#result = build_min_hours
#report_results(result, "outputs/output_min_hours.html")
