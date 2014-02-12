require 'mechanize'
require 'pp'
require 'uri'
require 'yaml'
require 'fileutils'
require 'pathname'
require 'isko/timetable-slot'
require 'isko/subject'
require 'isko/days'
require 'isko/cache'
require 'isko/semester'
require 'isko/exam-result'

module Isko
	class Agent
		class WrongFormat < StandardError; end
		class InvalidCredentials < StandardError; end

		def self.default_credentials
			YAML.load_file(Pathname.new("~/.sis-credentials.yml").expand_path)
		end

		def initialize(login: nil, password: nil, cache: nil)
			creds = self.class.default_credentials
			@login, @password = login || creds["login"], password || creds["password"]
			@cache = cache || Cache.new
			@agent = Mechanize.new
		end

		private
		attr_reader :cache

		public
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

		def exam_results
			link = main_page.link_with(text: /Výsledky zkoušek/) or raise "No link to exam results"
			page = link.click

			raise unless page.title =~ /Výsledky zkoušek - prohlížení/

			page.search("tr").map do |row|
				next unless row['class'] =~ /row[12]/

				conts = row.search("td").map(&:content)
				next unless conts[11] =~ /Splněno/

				kod, vysledek = conts[2], conts[6].gsub("Z", "")

				ExamResult.new(code: kod, result: (vysledek == "-" || vysledek.empty?) ? :credited : vysledek.to_i)
			end.compact
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
			cache_key = "subjects/#{code}.yml"
			return Subject.new(cache.load_yaml(cache_key)) if cache.contains?(cache_key)

			# TODO: cache it
			form = subject_search_form
			form.kod = code
			link = form.click_button.link_with(text: code.to_s)
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

			begin
				data = {
					code: code,
					name: name,
					semester: Semester.from_human(data["Semestr:"]),
					points: points,
					credits: credits
				}

				cache.save_yaml(cache_key, data)
				Subject.new(data)
			rescue WrongFormat => e
				raise "Wrong format of #{data.inspect}: #{e}"
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

			next_page = form.click_button
			link = next_page.link_with(text: code.to_s)
			raise "nemuzu otevrit predmet #{code}" unless link
			page = link.click

			raise "spatny rozvrh :(" if page_subtitle(page).include? "Archiv"

			page
		end

		def get_subject_timetable_slots(code)
			cache_key = "timetable_slots/#{code}.yml"

			return cache.load_yaml(cache_key) if cache.contains?(cache_key)

			page = subject_timetable_page(code)
			table = page.search('table.tab1').last

			rows = table.search('tr')
			raise unless rows.count > 0

			row_header = rows.shift.search('td').map(&:content).join(';')
			raise unless row_header =~ /Název předmětu;Učitelé;Čas;Učebna;Délka;Přihlášeno studentů \(kapacita\);Studenti/

			result = rows.map do |row|
				conts = row.search('td').map(&:content).map(&:strip)
				data = {
					code: conts[7], teacher: conts[9], start: conts[10],
					place: conts[11], time_minutes: conts[12].to_i,
					students_enrolled: conts[13].to_i, students_code: conts[14]
				}
			end

			cache.save_yaml(cache_key, result)
			result
		end

		def slot_timetable_page(code)
			page = subject_timetable_page(TimetableSlot.slot_code_to_subject_code(code))
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
end
