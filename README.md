# Goredis

goredis is intended to be a graphical version of redis "monitor" tool.
It captures network traffic via pcap to do so.

## building

You need Go 1.1, Ragel 6.8 and libpcap to build the project.

```
git clone https://github.com/hellvinz/goredis.git

ragel -Z -o src/cmd/goredis/main.go src/cmd/goredis/main.rl

gb build
```

### building the ui (optional)

```
cd ui
npm install -g yo
npm install -g generator-angular
npm install grunt
npm install
bower install
bundle
bundle exec grunt build
```

## running

```
sudo ./bin/goredis -d en0 -p 6379
```

where en0 is the interface you want to capture the traffic on

then navigate to http://thehost:12345, where thehost is where you have ran goredis

## limitations

capturing traffic on macos lo0 does not work yet (due to go-pcap)

tested only on macos/debian and chrome
