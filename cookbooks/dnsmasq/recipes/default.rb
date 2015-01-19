def default_value(val, default)
  if val.nil?
    return default
  end
  if val.is_a? Numeric
    return BigDecimal.new(val).to_i
  elsif val.downcase === 'true'
    return true
  elsif val.downcase === 'false'
    return false
  else
    return val
  end
end


def parseHosts(input) 
  if input.nil?
    return []
  end
  masqs = []
  input.split(',').each do |masq|
    theMasq = masq.split('=')
    masqs.push({
      :name => theMasq[0],
      :addr => theMasq[1]
    })
  end
  return masqs
end

def parseCsv(input) 
  if input.nil?
    return []
  end
  return input.split(',')
end

hostsConfig = {
  :hosts => parseHosts(ENV['hosts'])
}

nameserverConfig = {
  :nameservers => parseCsv(ENV['nameservers']),
  :search => parseCsv(ENV['search'])
}

dnsEnabled = default_value(ENV['tdns_enabled'], true)

if dnsEnabled === true

  cookbook_file 'dnsmasq.service.conf' do
    path '/etc/supervisord.d/dnsmasq.service.conf'
    action :create
  end

  template '/etc/dnsmasq.d/00hosts' do
    source 'hosts.erb'
    variables ({ :confvars => hostsConfig })
  end

  template '/etc/dnsmasq.conf' do
    source 'dnsmasq.conf.erb'
  end

  if nameserverConfig[:nameservers].length === 0
    file "/etc/resolv.dnsmasq.conf" do
      content ::File.open("/etc/resolv.conf").read
      action :create
    end
  else
    template '/etc/resolv.dnsmasq.conf' do
      source 'resolv.dnsmasq.conf.erb'
      variables ({ :confvars => nameserverConfig })
    end
  end

end
