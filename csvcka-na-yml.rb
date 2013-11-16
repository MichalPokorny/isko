#!/usr/bin/ruby -w

# Vezme si CSVcka rozvrhovych listku exportovana ze SISu a
# postavi si z nich cache.

require 'yaml'
require 'csv'

Dir["csvs/*.csv"].each do |f|
	data = CSV.read(f, col_sep: ';')
	data.shift

	kod = nil
	listky = data.map { |row|
		_, id_podlistku, kod_predmetu, _, den_1_po, cas, mistnost, delka_min, _, _, _, _, ucitele = row
		den_1_po = den_1_po.to_i
		cas = cas.to_i
		cas = "#{cas / 60}:%02d" % [cas % 60]
		raise kod_predmetu + " " + f if den_1_po == 0
		kod = kod_predmetu
		{
			code: id_podlistku,
			teacher: ucitele,
			start: "#{%w{XX Po Út St Čt Pá So Ne}[den_1_po]} #{cas}",
			place: mistnost,
			time_minutes: delka_min.to_i
		}
	}

	File.open("cache/timetable_slots/#{kod}.yml", "w") do |file|
		YAML.dump(listky, file)
	end
end
