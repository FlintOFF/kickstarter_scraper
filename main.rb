require 'pry'
require 'curb'
require 'nokogiri'
require 'json'
require 'csv'

url = "https://www.kickstarter.com/discover/advanced?state=successful&category_id=16&woe_id=0&pledged=3&goal=3&raised=2&sort=end_date&seed=2520203"
url.gsub!('&page=1', '')

curl = Curl::Easy.new
curl.follow_location = true
curl.max_redirects = 20
curl.timeout = 30
curl.connect_timeout = 10
curl.enable_cookies = true
curl.headers = {
  'accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
  'accept-encoding' => 'deflate, br',
  'accept-language' => 'en-US,en;q=0.9',
}
curl.ssl_verify_host = false
curl.ssl_verify_peer = false
curl.useragent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.75 Safari/537.36'

curl.url = url
curl.http_get

html = Nokogiri::HTML(curl.body_str)
projects_count = html.xpath(".//b[contains(@class, 'count')]").first.text.delete("\n").to_i
page_count = (projects_count.to_f/12).ceil

csrf_token = html.xpath(".//meta[@name='csrf-token']").first.attr('content')

default_header = {
  'accept' => 'application/json, text/javascript, */*; q=0.01',
  'X-CSRF-Token' => csrf_token,
  'X-Requested-With' => 'XMLHttpRequest',
  'accept-encoding' => 'deflate, br',
  'accept-Language' => 'en-US,en;q=0.9',
}

out = []
(1..page_count).each do |page|
  puts "Page #{page} of #{page_count}"

  curl.headers = default_header.dup
  curl.url = url.dup + "&page=#{page}"
  curl.http_get

  JSON.parse(curl.body)['projects'].each do |p|
    out << {
      name: p['name'],
      blurb: p['blurb'],
      goal: p['currency'] == 'USD' ? p['goal'].to_i : (p['goal'] * p['static_usd_rate']).to_i,
      pledged: p['currency'] == 'USD' ? p['pledged'].to_i : (p['pledged'] * p['static_usd_rate']).to_i,
      pledged_percent: (p['pledged']/p['goal']*100).ceil,
      state: p['state'],
      backers_count: p['backers_count'],
      category: p['category']['slug'],
      location: p['location']['short_name'],
      day_successful: p['state'] == 'successful' ? (p['state_changed_at'] - p['launched_at'])/60/60/24 : '',
      url: p['urls']['web']['project'],
    }
  end
  sleep(1)
end

CSV.open('out.csv', 'w') do |csv|
  csv << out.first.keys
  out.each do |row|
    csv << row.values
  end
end
