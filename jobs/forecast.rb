require 'net/https'
require 'json'
require 'rubygems'
require 'active_support/all'

# Forecast API Key from https://developer.forecast.io
forecast_api_key = ENV['FORECAST_IO_API_KEY']

# Latitude, Longitude for location
forecast_location_lat = ENV['FORECAST_LAT']
forecast_location_long = ENV['FORECAST_LONG']

# Unit Format
# "us" - U.S. Imperial
# "si" - International System of Units
# "uk" - SI w. windSpeed in mph
forecast_units = "us"

timezone = ActiveSupport::TimeZone.new("Eastern Time (US & Canada)")

SCHEDULER.every '10s', :first_in => 0 do |job|
  http = Net::HTTP.new("api.forecast.io", 443)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  response = http.request(Net::HTTP::Get.new("/forecast/#{forecast_api_key}/#{forecast_location_lat},#{forecast_location_long}?units=#{forecast_units}"))
  forecast = JSON.parse(response.body)
  forecast_current_temp = forecast["currently"]["temperature"].round
  forecast_current_icon = forecast["currently"]["icon"]
  forecast_current_desc = forecast["currently"]["summary"]
  if forecast["minutely"] # sometimes this is missing from the response. I don't know why
    forecast_next_desc = forecast["minutely"]["summary"]
    forecast_next_icon = forecast["minutely"]["icon"]
  else
    puts "Did not get minutely forecast data again"
    forecast_next_desc = "No data"
    forecast_next_icon = ""
  end
  forecast_later_desc = forecast["hourly"]["summary"]
  forecast_later_icon = forecast["hourly"]["icon"]
  event = {
      current_temp: "#{forecast_current_temp}&deg;",
      current_icon: "#{forecast_current_icon}",
      current_desc: "#{forecast_current_desc}",
      next_icon: "#{forecast_next_icon}",
      next_desc: "#{forecast_next_desc}",
      later_icon: "#{forecast_later_icon}",
      later_desc: "#{forecast_later_desc}"
  }
  forecast_hourly_data = forecast["hourly"]["data"].each_with_index do |data, index|
    event.merge!({
      "hourly_#{index}_icon".to_sym => data["icon"],
      "hourly_data_#{index}".to_sym => "#{Time.at(data['time']).to_datetime.in_time_zone(timezone).to_time.hour} #{data['temperature'].round}&deg;, #{((data['precipProbability'] || 0) * 100).round}%"
    })
  end
  send_event('forecast', event)
end