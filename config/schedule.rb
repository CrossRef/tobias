job_type :harvest, 'cd :path && DAYS=:days ACTION=:task bundle exec rake harvest_recent'

job_type :index_core, 'cd :path && CORE=:task OTHER=:then_swap_with bundle exec rake index_core'

every 2.days, :at => '11:00pm' do
  harvest 'dois', :days => 2
end

every :sunday, :at => '11:00pm' do
  index_core 'labs2', :then_swap_with => 'labs1'
end
  
