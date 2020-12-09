# CobaltStrike TeamServer Hunting

It is (or was, when this was written in 2016) trivial to identify poorly configured hosts running CobaltStrike's teamserver.

## How can we easily identify TeamServers ?

CobaltStrike's operator interface runs on port 50050. 

This service is wrapped in TLS.

The certificate presented on the service include static/common information in the Subject and Issuer:

Here's a snippet of the information which we're looking for:

```
---
Server certificate
subject=/C=Earth/ST=Cyberspace/L=Somewhere/O=cobaltstrike/OU=AdvancedPenTesting/CN=Major Cobalt Strike
issuer=/C=Earth/ST=Cyberspace/L=Somewhere/O=cobaltstrike/OU=AdvancedPenTesting/CN=Major Cobalt Strike
---
```

Yeah. It's as simple as "we're going to grep for Cobalt Strike on a large dataset

But before you get turned off the idea, lets consider the benefits of identifying a team server.

Since CobaltStrike will present its "target facing" or C2 services on the same IP address. 

Once we've identified a TeamServer we can conduct a full service scan to identify any other interesting services which may be running.

In this case, I focussed on:

1. Identifying poorly configured TeamServers
2. Identifying additional listening services on the TeamServer
3. Extracting information from any certificates presented by these services
4. Grabbing screenshots of any web services

This project was put together to perform weekly audits of some large internet ranges in an attempt to identify and catalog poorly configured CobaltStrike team servers.

# Results ?

Over a period of a few years, I netted a chunky dataset full of domain names screenshots of phishing pages.

It's an interesting catalog.

## How does this work ?

In a nutshell, here's the process:

1. masscan a bunch of ranges looking for port 50050
2. Interrogate the service to retrieve the certificate
3. Filter on this "OU=AdvancedPenTesting/CN=Major Cobalt Strike"
4. Perform a full port scan
5. Interrogate any open ports - grab the certificate information
6. Pull out domain information from any recovered certificates
7. Grab some screenshots of any web services

## Is this technique still valid ?

:shrug: I've no idea if CobaltStrike continues to demonstrate this behaviour.

## Mitigation

Lets just assume you should employ good practice and restrict access to the service, rather than hope that this isn't possible any more.

## What network ranges were scanned ?

I hunted down the ranges used by some of the biggest cloud providers and built a list of network CIDRS.

I've got a catalog of 4906 networks listed, the CIDRS seem to range from /12-/32. Yikes. Masscan made frighteningly light work out of them.

I've not included the network ranges in this release

## Pre-Reqs 


If you're using kali, you *should* be able to run this script with this set of scripts installed:

```
apt-get -y install libpcap-dev screen nmap eyewitness masscan default-jre exploitdb amap socat supervisor tor proxychains parallel netcat
```
