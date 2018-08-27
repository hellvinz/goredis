package main

import (
	"encoding/json"
	"flag"
	"fmt"
	eventsource "github.com/antage/eventsource"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"github.com/google/gopacket/pcap"
	"github.com/hellvinz/goredis/src/redis_protocol"
	"net/http"
)

func notifyClients(rediscommand_ch <-chan redis_protocol.RedisCommand, es eventsource.EventSource) {
	for {
		select {
		case command := <-rediscommand_ch:
			b, err := json.Marshal(command)
			if err != nil {
				fmt.Println("error:", err)
			} else {
				es.SendEventMessage(string(b), "", "")
			}
		}
	}
}

func setupEventSource(rediscommand_ch <-chan redis_protocol.RedisCommand) {
	es := eventsource.New(nil, nil)
	defer es.Close()
	go notifyClients(rediscommand_ch, es)
	http.Handle("/redis", es)
	http.Handle("/", http.FileServer(http.Dir("./ui/dist")))
	err := http.ListenAndServe(":12345", nil)
	if err != nil {
		panic("ListenAndServe: " + err.Error())
	}
}

func setupPcap(device *string, port *string, rediscommand_ch chan<- redis_protocol.RedisCommand) {
	var h *pcap.Handle
	var err error

	ifs, err_str := pcap.FindAllDevs()
	if len(ifs) == 0 {
		fmt.Printf("Warning: no devices found : %s\n", err_str)
	}

	h, err = pcap.OpenLive(*device, int32(65535), true, 1000)
	if h == nil {
		fmt.Printf("Openlive(%s) failed: %s\n", *device, err)
		return
	}
	defer h.Close()

	err = h.SetBPFFilter("dst port " + *port)
	if err != nil {
		fmt.Println("set filter failed")
		return
	}

	packetSource := gopacket.NewPacketSource(h, h.LinkType())
	for pkt := range packetSource.Packets() {
		applicationLayer := pkt.ApplicationLayer()

		if applicationLayer == nil {
			continue
		}

		s := string(applicationLayer.Payload())

		if s == "" {
			continue
		}

		rediscommand, err := redis_protocol.Parse(s)
		if err != nil {
			fmt.Println(err)
			continue
		}

		ipLayer := pkt.Layer(layers.LayerTypeIPv4)
		if ipLayer != nil {
			ip, _ := ipLayer.(*layers.IPv4)
			rediscommand.Ipaddr = []byte(ip.SrcIP.String())
		} else {
			ipLayer := pkt.Layer(layers.LayerTypeIPv6)
			if ipLayer != nil {
				ip, _ := ipLayer.(*layers.IPv6)
				rediscommand.Ipaddr = []byte(ip.SrcIP.String())
			}
		}
		rediscommand_ch <- *rediscommand
	}
}

func main() {
	var device *string = flag.String("d", "", "device")
	var port *string = flag.String("p", "6379", "port")
	flag.Parse()

	rediscommand_ch := make(chan redis_protocol.RedisCommand)

	go setupEventSource(rediscommand_ch)
	setupPcap(device, port, rediscommand_ch)
}
