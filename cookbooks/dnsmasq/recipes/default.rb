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

hostsConfig = {
  :hosts => parseHosts(ENV['hosts'])
}

def parseNameservers(input) 
  if input.nil?
    return []
  end
  return input.split(',')
end

nameserverConfig = {
  :nameservers => parseNameservers(ENV['nameservers'])
}

template '/etc/dnsmasq.d/00hosts' do
  source 'hosts.erb'
  variables ({ :confvars => hostsConfig })
end

template '/etc/dnsmasq.conf' do
  source 'dnsmasq.conf.erb'
end

template '/etc/resolv.dnsmasq.conf' do
  source 'resolv.dnsmasq.conf.erb'
  variables ({ :confvars => nameserverConfig })
end
