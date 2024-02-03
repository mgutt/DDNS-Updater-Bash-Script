#!/bin/bash
# #####################################
# Script:      DDNS Updater v1.3
# Description: Opens a DDNS URL to update the IPv4 and/or IPv6.
# Author:      Marc Gutt
# 
# Manual:
# - Execute this script every 5 minutes through a custom cron schedule like: */5 * * * *
# ######### Settings ##################

# set your ddns domain(s)
domains=(
  "sub1.example.com"
  "sub2.example.com"
)

# set your DDNS API login
users=(
  "login1"
  "login2"
)
passwords=(
  "pass1"
  "pass2"
)

# choose your DDNS provider
providers=(
  "allinkl"
  "dynu"
)

# obtain IPv4 of routers DDNS address
ipv4_public=$(dig xxx.myfritz.net A +short)

# obtain ipv6 of br0 device
ipv6_public=$(ip -6 addr show dev br0 scope global -deprecated | grep -oP "(?<=inet6 )[^/]+" | head -n 1)

# ######### Script ####################

# make script race condition safe
if [[ -d "/tmp/${0///}" ]] || ! mkdir "/tmp/${0///}"; then exit 1; fi; trap 'rmdir "/tmp/${0///}"' EXIT;

# loop through domains
for i in "${!domains[@]}"; do

  # set vars
  domain="${domains[i]}"
  subdomain=$(echo "$domain" | cut -f1 -d'.' ) # obtain "foo" from "foo.example.com"
  user="${users[i]}"
  password="${passwords[i]}"
  provider="${providers[i]}"
  ipv4_domain=$(dig "$domain" A +short)
  ipv6_domain=$(dig "$domain" AAAA +short)

  # check if ipv4 needs an update
  unset ipv4
  if [[ $ipv4_public != "$ipv4_domain" ]]; then
    echo "$domain returns IP $ipv4_domain and needs to be updated to $ipv4_public"
    ipv4=$ipv4_public
  fi

  # check if ipv6 needs an update
  unset ipv6
  if [[ $ipv6_public != "$ipv6_domain" ]]; then
    echo "$domain returns IP $ipv6_domain and needs to be updated to $ipv6_public"
    ipv6=$ipv6_public
  fi

  # update IP through DDNS API
  if [[ "$ipv4" ]] || [[ "$ipv6" ]]; then
    case $provider in
    "allinkl")
        url="https://${user}:${password}@dyndns.kasserver.com/?myip=${ipv4}&myip6=${ipv6}"
        ;;
    "duckdns")
        url="https://www.duckdns.org/update?domains=${subdomain}&token=${password}&ip=${ipv4}&ipv6=${ipv6}"
        ;;
    "dynu")
        url="http://api.dynu.com/nic/update?hostname=${domain}&myip=${ipv4}&myipv6=${ipv6}&password=${password}"
        ;;
    # You need to add "google" twice if you like to update IPv4 and IPv6!
    "google")
        url="https://${user}:${password}@domains.google.com/nic/update?hostname=${domain}&myip={ipv4}{ipv6}"
        ;;
    esac
    echo "curl $url"
    if ! curl --silent --show-error "$url"; then
      echo "Error: Something went wrong while calling the DDNS api of $provider"
    fi
    continue
  fi

done
