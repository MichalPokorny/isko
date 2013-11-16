#!/usr/bin/ruby -w

$: << '.'
require 'sis-agent'

agent = SisAgent.new
instances = agent.all_slot_instances(ARGV[0] || "13aNTVY016x02") # telak

passed = instances.count { |inst| Date.today > inst }
remaining = instances.size - passed
puts(sprintf("Passed: #{passed}, remaining: #{remaining} (%.2f%%)", (passed.to_f * 100)/instances.size))

