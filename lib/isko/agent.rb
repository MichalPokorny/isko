require 'mechanize'
require 'csv'
require 'date'
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
require 'isko/subject-code'

module Isko
	class Agent
		class WrongFormat < StandardError; end
		class InvalidCredentials < StandardError; end

		class Credentials
			def self.default
				hash = YAML.load_file(Pathname.new('~/Dropbox/secrets/sis-credentials.yml').expand_path)
				Credentials.new(login: hash['login'], password: hash['password'])
			end

			def initialize(login: nil, password: nil)
				@login, @password = login, password
			end

			attr_reader :login, :password
		end

		def initialize(credentials: nil, cache: nil)
			@credentials = credentials || Credentials.default
			@cache = cache || Cache.new
			@agent = Mechanize.new

			@main_page = nil
		end

		protected
		attr_reader :cache

		public

		def main_page
			return @main_page if @main_page
			page = @agent.get('https://is.cuni.cz/studium/index.php')
			form = page.form_with(name: 'flogin')
			form.login = @credentials.login
			form.heslo = @credentials.password
			page = form.click_button

			raise InvalidCredentials if page.content.include? 'Zadali jste nespr' # avne prihlasovaci udaje...

			@main_page = page or raise

			page
		end

		def warning(*args)
			puts(*args)
		end

		def exam_results
			link = main_page.link_with(text: /Výsledky zkoušek/) or raise "No link to exam results"
			page = link.click

			raise unless page.title =~ /Výsledky zkoušek - prohlížení/
			form = page.form_with(id: 'skrform')

			# XXX: hacky way of enabling every year
			# TODO: dynamically select everything
			form.checkboxes.each { |field|
				field.checked = true
			}
			page = form.click_button

			page.search("tr").map do |row|
				next unless row['class'] =~ /row[12]/

				conts = row.search("td").map(&:content)
				next unless conts[11] =~ /Splněno/

				kod, vysledek = conts[2], conts[6].gsub("Z", "")

				unless SubjectCode.is_valid_mff?(kod)
					warning "Skipping non-MFF subject: #{kod}"
					next
				end

				ExamResult.new(
					code: kod,
					result: (vysledek == "-" || vysledek.empty?) ? :credited : vysledek.to_i
				)
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

		private

		def parse_requirements(raw_text)
			if raw_text =~ /.+ (Z|Zk|Z\+Zk|KZ|Z\(\+Zk\)) (\[hodiny\/týden\]|\[dny\/semestr\]|\[\])$/
				$1
			else
				raise WrongFormat, "Can't parse requirements: '#{raw_text}'"
			end
		end

		public

		# TODO: dump page.body for inspection on most failures to click on stuff

		def get_subject_by_code(code)
			results = try_cache("subjects/#{code}.yml") do
				puts "Cache miss: downloading subject metadata for [#{code}]"
				# TODO: cache it
				form = subject_search_form
				form.kod = code
				results_page = form.click_button
				link = results_page.link_with(text: code.to_s)
				raise "nemuzu otevrit predmet #{code}" unless link
				page = link.click
				raise unless page.title =~ /Předměty/
				raise unless page_subtitle(page) =~ /Předmět/

				table = page.search('.form_div table.tab2').first
				raise unless table

				data = table.search("tr").to_a.map { |row|
					[row.search("th").first.content, row.search("td").first.content]
				}.to_h

				title = page.search('div.form_div_title').last.content
				raise unless title =~ /(.+) - #{code}$/
				name = $1

				credits =
					if data["E-Kredity:"] =~ /#{data["Semestr:"]} s\.:(\d+)$/
						$1
					elsif data["E-Kredity:"].strip =~ /^(\d+)$/
						$1
					else
						raise WrongFormat, "Unknown format: #{data["E-Kredity:"]}"
					end.to_i

				begin
					{
						code: code,
						name: name,
						semester: Semester.from_human(data["Semestr:"]),
						credits: credits,
						requirements: parse_requirements(data['Rozsah, examinace:'])
					}
				rescue WrongFormat => e
					raise "Wrong format of #{data.inspect}: #{e}"
				end
			end

			Subject.new(results)
		end

		def get_subject_name(code)
			begin
				get_subject_by_code(code).name
			rescue
				puts "Error while getting name of subject #{code}"
				raise
			end
		end

		def get_subject_credits(code)
			get_subject_by_code(code).credits
		end

		def timetable_ng_page
			return @timetable_ng_page if defined?(@timetable_ng_page) && @timetable_ng_page
			page = main_page.link_with(text: /Rozvrh NG/).click
			raise unless page.title =~ /Rozvrh NG/
			@timetable_ng_page = page
		end

		private
		def parse_timetable_csv(page)
			data = page.body.force_encoding('Windows-1250').encode('UTF-8')
			CSV.parse(data, col_sep: ?;)
		end

		public
		def my_timetable_csv
			page = timetable_ng_page.link_with(href: /roz_muj_macro/).click
			parse_timetable_csv(page.link_with(href: /&csv=1$/).click)
		end

		def chosen_timetable_csv
			page = timetable_ng_page
			form = page.form_with(name: "filtr")
			form['rezim'] = "kosik"
			page = form.click_button

			raise unless page.search('#tip').map(&:content).join =~ /pro definici a zobrazen/ # i vlasniho rozvrhu

			parse_timetable_csv(page.link_with(href: /&csv=1$/).click)
		end

		private
		def check_csv_format!(csv)
			raise "Neznamy format" unless csv.shift == ["id listku(veskera vyuka pro celou paralelku - vice hodin za tyden)",
				"id podlistku(konkretni vyuka v nejaky den a hodinu)",
				"kod predmetu", "nazev", "den(1=po)", "cas(min od 0:00)", "mistnost",
				"delka(min)", "prvni tyden vyuky", "prvni den vyuky pro jednorazovou",
				"pocet tydnu vyuky", "ctrnactideni vyuka", "ucitele"]
			csv
		end

		public
		def my_timetable_slot_codes
			check_csv_format!(my_timetable_csv).map(&:first)
		end

		def chosen_timetable_slot_codes
			check_csv_format!(chosen_timetable_csv).map(&:first)
		end

		def subject_timetable_search_page
			return @subject_timetable_search_page if defined?(@subject_timetable_search_page) && @subject_timetable_search_page
			page = timetable_ng_page.link_with(href: /roz_predmet_find/).click
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

		private

		def try_cache(key)
			if cache.contains?(key)
				cache.load_yaml(key)
			else
				result = yield
				cache.save_yaml(key, result)
				result
			end
		end

		public

		def get_subject_timetable_slots(code)
			result = try_cache("timetable_slots/#{code}.yml") do
				puts "Cache miss: downloading slots of subject #{code}"
				page = subject_timetable_page(code)
				table = page.search('table.tab1').last

				rows = table.search('tr')
				raise unless rows.count > 0

				row_header = rows.shift.search('td').map(&:content) #.join(';')

				content_hashes = rows.map do |content_row|
					row_hash = {}
					row_header.zip(content_row.search('td').map(&:content)).each do |key_value_pair|
						key, value = key_value_pair
						next if key.empty?
						raise if row_hash.key?(key)
						row_hash[key] = value
					end
					row_hash
				end

				content_hashes.map do |row|
					{
						code: row.fetch('Kód lístku ( typ)'),
						teacher: row.fetch('Učitelé'),
						start: row.fetch('Čas'),
						place: row.fetch('Učebna').strip,
						duration_minutes: row.fetch('Délka').to_i,
						enrolled_students: row.fetch('Přihlášeno studentů (kapacita)').to_i,
						students_code: row.fetch('Studenti')
					}
				end
			end

			result.map { |hash| TimetableSlot.new(hash) }
		end

		def get_timetable_slot(code)
			code = SlotCode.new(code)
			get_subject_timetable_slots(code.subject_code).select { |slot|
				slot.code == code
			}.first
		end

		def slot_timetable_page(code)
			page = subject_timetable_page(SlotCode.new(code).subject_code)
			page.link_with(href: /#{code}/).click
		end

		def finished_subject_codes
			exam_results.map(&:code)
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

		def all_cs_slot_codes
			try_cache("#{Date.today.strftime('%Y-%m-%d')}/all_cs_slots") do
				buildings_page = timetable_ng_page.link_with(text: 'Budovy').click
				# TODO: dynamic
				bldg_page = buildings_page.link_with(text: 'Malostranské nám. 25, 118 00 Praha 1 (NMS)').click
				%w{Pondělí Úterý Středa Čtvrtek Pátek}.flat_map do |day|
					day_page = bldg_page.link_with(text: day).click
					csv = parse_timetable_csv(day_page.link_with(href: /&csv=1$/).click)
					check_csv_format!(csv).map(&:first)
				end.compact  # reservations have no slot code
			end
		end
	end
end
