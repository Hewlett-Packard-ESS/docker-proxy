def parseDnsmasq(input) 
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

dnsmasqConfig = {
  :hosts => parseDnsmasq(ENV['dnsmasq'])
}

template '/etc/dnsmasq.d/00hosts' do
  source 'dnsmasq.conf.erb'
  variables ({ :confvars => dnsmasqConfig })
end
