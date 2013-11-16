require 'mechanize'
require 'pp'
require 'uri'
require 'yaml'
require 'fileutils'
require 'pathname'

class SisAgent
	class Subject
		def initialize(code: nil, name: nil, semester: nil, points: nil, credits: nil)
			@code, @name, @semester, @points, @credits = code, name, semester, points, credits
		end

		attr_reader :code, :name, :semester, :points, :credits
	end

	class WrongFormat < StandardError; end
	class InvalidCredentials < StandardError; end

	def self.default_credentials
		YAML.load_file(Pathname.new("~/.sis-credentials.yml").expand_path)
	end

	def initialize(login: nil, password: nil)
		creds = self.class.default_credentials
		@login, @password = login || creds["login"], password || creds["password"]
		@agent = Mechanize.new
	end

	def main_page
		return @main_page if defined?(@main_page) && @main_page
		page = @agent.get('https://is.cuni.cz/studium/index.php')
		form = page.form_with(name: 'flogin')
		form.login = @login
		form.heslo = @password
		page = form.click_button

		raise InvalidCredentials if page.content.include? "Zadali jste nespr" # avne prihlasovaci udaje...

		@main_page = page or raise

		page
	end

	def vysledky_zkousek
		predmety = []
		link = main_page.link_with(text: /Výsledky zkoušek/) or raise "No link to exam results"
		page = link.click

		raise unless page.title =~ /Výsledky zkoušek - prohlížení/

		rows = page.search("tr")

		rows.each do |row|
			next unless row['class'] =~ /row[12]/

			conts = row.search("td").map(&:content)
			kod, jmeno, kredity, vysledek = conts[2], conts[3], conts[10].to_i, conts[6]

			vysledek.gsub! "Z", ""

			next unless conts[11] =~ /Splněno/

			predmet = {
				code: kod, name: jmeno, credits: kredity
			}

			unless vysledek == "-" || vysledek.empty?
				vysledek = vysledek.to_i
				predmet[:result] = vysledek
			end

			predmety << predmet
		end

		predmety
	end

	def page_subtitle(page)
		page.search('span#stev_podtitul_modulu').first.content
	end

	def subject_search_page
		return @subject_search_page if defined?(@subject_search_page) && @subject_search_page
		link = main_page.link_with(text: /Předměty/) or raise "No subjects link"
		page = link.click
		raise unless page.title =~ /Předměty/ && page_subtitle(page) =~ /Hledání v předmětech/
		@subject_search_page = page
		page
	end

	def subject_search_form
		subject_search_page.form_with(id: 'filtr') or raise "subject search form not found"
	end

	def get_subject_by_code(code)
		file = "cache/subjects/#{code}.yml"

		return Subject.new(YAML.load_file(file)) if File.exist?(file)

		# TODO: cache it
		form = subject_search_form
		form.kod = code
		link = form.click_button.link_with(text: code)
		raise "nemuzu otevrit predmet #{code}" unless link
		page = link.click
		raise unless page.title =~ /Předměty/
		raise unless page_subtitle(page) =~ /Předmět/

		table = page.search('.form_div table.tab2').first
		raise unless table

		data = {}
		table.search("tr").to_a.map { |row|
			data[row.search("th").first.content] = row.search("td").first.content
		}

		title = page.search('div.form_div_title').last.content
		raise unless title =~ /(.+) - #{code}$/
		name = $1

		points =
			if data["Body:"] =~ /#{data["Semestr:"]} s.:(\d+)$/
				$1
			elsif data["Body:"] =~ /^ *(\d+)$/
				$1
			else
				raise WrongFormat, "Unknown format: #{data["Body:"]}"
			end.to_i

		credits = 
			if data["E-Kredity:"] =~ /#{data["Semestr:"]} s.:(\d+)$/
				$1
			elsif data["E-Kredity:"] =~ /^ *(\d+)$/
				$1
			else
				raise WrongFormat, "Unknown format: #{data["E-Kredity:"]}"
			end.to_i

		data = {
			code: code,
			name: name,
			semester: self.class.parse_semester_name(data["Semestr:"]),
			points: points,
			credits: credits
		}

		File.open(file, "w") do |f| YAML.dump(data, f) end
		Subject.new(data)
	end

	def self.parse_semester_name(name)
		case name
		when "letní" then :summer
		when "zimní" then :winter
		else raise WrongFormat, "unknown semestr #{name}"
		end
	end

	def self.semester_to_human(semester)
		case semester
		when :summer then "letní"
		when :winter then "zimní"
		else raise WrongFormat
		end
	end

	def self.semester_to_i(semester)
		case semester
		when :summer then 1
		when :winter then 2
		else raise WrongFormat
		end
	end

	def get_subject_name(code)
		get_subject_by_code(code).name
	end

	def get_subject_credits(code)
		get_subject_by_code(code).credits
	end

	def subject_timetable_search_page
		return @subject_timetable_search_page if defined?(@subject_timetable_search_page) && @subject_timetable_search_page
		page = main_page.link_with(text: /Rozvrh NG/).click
		raise unless page.title =~ /Rozvrh NG/
		page = page.link_with(href: /roz_predmet_find/).click
		raise "On wrong page: #{page.uri}, expecting subject search" unless page.uri.to_s =~ /roz_predmet_find\.php/
		@subject_timetable_search_page = page
	end

	def subject_timetable_page(code)
		form = subject_timetable_search_page.form_with(name: 'filtr') or raise "Subject search form not found"
		form.kod = code
		
		link = form.click_button.link_with(text: code)
		raise "nemuzu otevrit predmet #{code}" unless link
		page = link.click

		raise "spatny rozvrh :(" if page_subtitle(page).include? "Archiv"

		page
	end

	def get_subject_timetable_slots(code)
		FileUtils.mkdir_p('cache/timetable_slots')
		FileUtils.mkdir_p('cache/subjects')
		file = "cache/timetable_slots/#{code}.yml"

		return YAML.load_file(file) if File.exist? file

		page = subject_timetable_page(code)
		table = page.search('table.tab1').last

		rows = table.search('tr')
		raise unless rows.count > 0 && rows.shift.search('td').map(&:content).join(';') =~ /Název předmětu;Učitelé;Čas;Učebna;Délka;Přihlášeno studentů;Studenti/

		result = rows.map do |row|
			conts = row.search('td').map(&:content).map(&:strip)
			{
				code: conts[7], teacher: conts[9], start: conts[10], place: conts[11], time_minutes: conts[12].to_i, students_enrolled: conts[13].to_i, students_code: conts[14]
			}
		end

		File.open(file, "w") do |f| YAML.dump(result, f) end
		result
	end

	def self.slot_weird?(a)
		a[:start].empty?
	end

	def self.slot_start_day(slot)
		unless slot[:start] =~ /\A(.+) (\d+):(\d+)\Z/
			p slot
			raise
		end
		raise WrongFormat unless DAYS.include? $1
		return $1
	end

	def self.slot_absolute_start(slot)
		unless slot[:start] =~ /\A(.+) (\d+):(\d+)\Z/
			p slot
			raise
		end
		raise WrongFormat unless DAYS.include? $1
		return ($2.to_i * 60) + $3.to_i
	end

	def self.slot_time_collision?(a, b_start, b_end)
		a_start = a[:start]
		a_time = a[:time_minutes]

		a_start = slot_absolute_start(a)
		a_end = a_start + a_time

		return ! ((a_end <= b_start) || (b_end <= a_start))
	end

	def self.slot_collision(a, b)
		a_start, b_start = a[:start], b[:start]
		a_time, b_time = a[:time_minutes], b[:time_minutes]

		a_day, a_start = slot_start_day(a), slot_absolute_start(a)
		b_day, b_start = slot_start_day(b), slot_absolute_start(b)

		return false unless a_day == b_day
		a_end = a_start + a_time
		b_end = b_start + b_time

		return ! ((a_end <= b_start) || (b_end <= a_start))
	end

	def self.slot_code_to_subject_code(code)
		# (rok)a(predmet)[xp](\d+)b*
		# rok: 12/13
		#
		# 13aNMAG333p1
		unless code =~ /\A(\d{2})a(.{4}\d{3})[xp](\d+)[abcdef]*&*\Z/
			pp code
			raise
		end
		$2
	end

	def self.slot_code_to_type(code)
		raise unless code =~ /\A(\d{2})a(.{4}\d{3})([xp])(\d+)[abcdef]*&*\Z/
		{
			x: :cviceni, p: :prednaska
		}[$3.to_sym]
	end

	DAYS = %w{Po Út St Čt Pá}

	def slot_timetable_page(code)
		page = subject_timetable_page(self.class.slot_code_to_subject_code(code))
		page.link_with(href: /#{code}/).click
	end

	def all_slot_instances(code)
		page = slot_timetable_page(code)
		tables = page.search("table.tab1").select { |table|
			elem = table.search("tr.head1 td").first
			elem && elem.content.include?("Týden")
		}
		raise unless tables.size == 1
		table = tables.first
		table.search("tr").select { |row|
			(!row.attributes["class"].value.include?("row4")) && # cancelled
			row.search("td").first.content.strip =~ /\d+/
		}.map { |row|
			Date.parse(row.search("td")[1].content)
		}
	end
end
