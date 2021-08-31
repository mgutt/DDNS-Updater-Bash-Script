#!/bin/bash
# #####################################
# Script:      DDNS Updater v0.9
# Description: Opens a DDNS URL to update the IPv4 and/or IPv6.
# Author:      Marc Gutt
# 
# Manual:
# - Execute this script every 5 minutes through a custom cron schedule like: */5 * * * *
# - Execute "rm /tmp/*.ddns" to remove all files generated through this script
# 
# ######### Settings ##################

# set your ddns domain(s)
domains=(
  "sub.example.com"
  "sub"
)

# set your DDNS API login
users=(
  "dyn1234"
  "username"
)
passwords=(
  "password"
  "1234-1234-1234-1234-1234"
)

# set IPv4
# Options:
# - public IPv4: "icanhazip.com"
# - fixed IPv4: "1.2.3.4"
ipv4s=(
  "icanhazip.com"
  "icanhazip.com"
)

# set IPv6
# Options:
# - container's IPv6: $(docker inspect "containername" --format='{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}')
# - public IPv6: "icanhazip.com"
# - fixed IPv6: "1234:1234:1234::1234"
# - server's IPv6: $(hostname -I | egrep -o '[0-9a-z:]+:[0-9a-z:]+' | head -n 1)
ipv6s=(
  $(docker inspect "containername" --format='{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}')
  $(hostname -I | egrep -o '[0-9a-z:]+:[0-9a-z:]+' | head -n 1)
)

# choose your DDNS provider
providers=(
  "allinkl"
  "duckdns"
)

# ######### Script ####################
# make script race condition safe
if [[ -d "/tmp/${0///}" ]] || ! mkdir "/tmp/${0///}"; then exit 1; fi; trap 'rmdir "/tmp/${0///}"' EXIT;

# loop through domains
for i in ${!domains[@]}; do

  # set vars
  domain="${domains[i]}"
  subdomain=$(echo "$domain" | cut -f1 -d'.' ) # obtain "foo" from "foo.example.com"
  tld=${domain#$subdomain.} # obtain "example.com" from "foo.example.com"
  user="${users[i]}"
  password="${passwords[i]}"
  provider="${providers[i]}"
  ipv4="${ipv4s[i]}"
  ipv6="${ipv6s[i]}"
  ipv4lastapi="none"
  ipv6lastapi="none"
  ipv4lastfilename="none"
  ipv6lastfilename="none"

  # files to store IP addresses
  ipv4filename="/tmp/ipv4.${domain}.ddns"
  ipv6filename="/tmp/ipv6.${domain}.ddns"
  ipv4lastcheck="/tmp/ipv4.lastcheck.${domain}.ddns"
  ipv6lastcheck="/tmp/ipv6.lastcheck.${domain}.ddns"

  # obtain public IPv4
  if [[ -n "$ipv4" ]] && [[ "$ipv4" =~ ^[0-9.]+$ ]]; then
    # Check if we already obtained the IP from the external service
    if [[ $ipv4lastapi != $ipv4 ]]; then
      lastcheck=$(stat -c %Y "$ipv4lastcheck")
      # obtain public IPv4 only every 5 minutes to avoid DDoS'ing the external service
      if [[ $lastcheck -lt $(date -d "-5 minutes" +"%s") ]]; then
        ipv4lastapi=$ipv4
        ipv4lastfilename=$ipv4filename
        ipv4=$(curl -4 ${ipv4})
        touch "$ipv4lastcheck"
      else
        ipv4=$(cat "$ipv4filename")
      fi
    elif
      ipv4=$(cat "$ipv4lastfilename")
    fi
  fi

  # obtain public IPv6
  if [[ -n "$ipv6" ]] && [[ "$ipv6" =~ ^[0-9a-z:/]+$ ]]; then
    # Check if we already obtained the IP from the external service
    if [[ $ipv6lastapi != $ipv6 ]]; then
      lastcheck=$(stat -c %Y "$ipv6lastcheck")
      # obtain public IPv6 only every 5 minutes to avoid DDoS'ing the external service
      if [[ $lastcheck -lt $(date -d "-5 minutes" +"%s") ]]; then
        ipv6lastapi=$ipv6
        ipv6lastfilename=$ipv6filename
        ipv6=$(curl -6 ${ipv6})
        touch "$ipv6lastcheck"
      else
        ipv6=$(cat "$ipv6filename")
      fi
    elif
      ipv6=$(cat "$ipv6lastfilename")
    fi
  fi

  # check if DDNS IP update is necessary
  if [[ $(cat "$ipv4filename") != "$ipv4" ]] || [[ $(cat "$ipv6filename") != "$ipv6" ]]; then
    # write new IPs to files
    echo "${ipv4}" > "$ipv4filename"
    echo "${ipv6}" > "$ipv6filename"
    # update IP through DDNS API
    case $provider in
    "allinkl")
        url="https://${user}:${password}@dyndns.kasserver.com/?myip=${ipv4}&myip6=${ipv6}"
        ;;
    "duckdns")
        url="https://www.duckdns.org/update?domains=${domain}&token=${password}&ip=${ipv4}&ipv6=${ipv6}"
        ;;
    esac
    curl $url
    echo $url
  fi

done
