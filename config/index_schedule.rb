job_type :index_core, 'cd :path && CONFIG=:config CORE=:task OTHER=:then_swap_with bundle exec rake index_core'

very :sunday, :at => '11:00pm' do
  index_core 'labs2', :then_swap_with => 'labs1'
end
