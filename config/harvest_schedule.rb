job_type :harvest, 'cd :path && CONFIG=:config DAYS=:days ACTION=:task bundle exec rake harvest_recent > last_harvest.log.txt'

every 2.days, :at => '11:00pm' do
  harvest 'dois', :days => 2
end
