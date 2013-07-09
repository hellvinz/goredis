# Goredis

goredis is intended to be a graphical version of redis "monitor" tool.
It captures network traffic via pcap to do so.

## building

You need Go 1.1 and Ragel 6.8 to build the project.

```
ragel -Z -o goredis.go goredis.rl

go build goredis.go
```

## running

```
sudo ./goredis -i en0 -p 6379
```

where en0 is the interface you want to capture the traffic on

then navigate to http://localhost:12345

## limitations

capturing traffic on lo0 does not work yet

tested only on macos
