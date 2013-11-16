#!/usr/bin/ruby -w

$: << '.'
require 'sis-agent'

# simulovane znamky: -s (znamka:kredity) (znamka:kredity) ...
znamky_navic = []
if ARGV[0] == "-s"
	ARGV.shift

	while ARGV.length > 0 && ARGV[0].index(":")
		znamky_navic << ARGV.shift.split(":").map(&:to_i)
	end
end

agent = SisAgent.new
predmety = agent.vysledky_zkousek

predmety.each do |predmet|
	puts "#{predmet[:code]} #{predmet[:name]} (#{predmet[:credits]} kr.): #{predmet[:result] || 'OK'}"
end

creds = predmety.map{|x| x[:credits]}.inject(&:+)
zkouskove = predmety.select{|x| x.key?(:result)}
creds_zk = zkouskove.map{|x| x[:credits]}.inject(&:+)

soucet_znamek = zkouskove.map{|x| x[:result]}.inject(&:+).to_f
soucet_vazenych_znamek = zkouskove.map{|x| x[:result]*x[:credits]}.inject(&:+).to_f

pocet_predmetu = zkouskove.count

znamky_navic.each { |zn|
	znamka, kredity = *zn

	puts "        + #{znamka}, #{kredity} kr"

	soucet_znamek += znamka
	soucet_vazenych_znamek += znamka * kredity
	creds_zk += kredity
	creds += kredity
	pocet_predmetu += 1
}

avg = soucet_znamek / pocet_predmetu
cavg = soucet_vazenych_znamek / creds_zk

puts "Nevazeny prumer: %.3f   Kreditove vazeny prumer: %.3f" % [ avg, cavg ]
puts "Celkem kreditu se znamkami: %d    Celkem kreditu: %d" % [ creds_zk, creds ]

# TODO: scitani poctu kreditu
