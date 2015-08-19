package main;
import(
    "flag"
    "errors"
    "fmt"
    "net/http"
    eventsource "github.com/antage/eventsource"
    "github.com/miekg/pcap"
    "encoding/json"
)

type RedisCommand struct {
    argnum int;
    argsize int;
    cur_arg int;
    cur_arg_char int;
    Args [][]byte;
    args_sizes []int;
    Ipaddr []byte;
}

var clients = make([]chan<- RedisCommand, 0)

var cs int

%%{
  machine RedisParser;

  action argnum_add_digit { 
    redisCommand.argnum = redisCommand.argnum * 10 + (int(fc)-'0');
  }
  action argsize_reset { redisCommand.argsize = 0; }
  action argsize_add_digit { redisCommand.argsize = redisCommand.argsize * 10 + (int(fc)-'0'); }
  action args_init {
    redisCommand.cur_arg = -1;
    redisCommand.Args = make([][]byte,redisCommand.argnum);
    redisCommand.args_sizes = make([]int,redisCommand.argnum);
  }
  action arg_init {
    redisCommand.cur_arg++;
    redisCommand.cur_arg_char = 0;
    redisCommand.args_sizes[redisCommand.cur_arg] = redisCommand.argsize;
    redisCommand.Args[redisCommand.cur_arg] = make([]byte,redisCommand.argsize);
  }
  action test_arg_len { redisCommand.cur_arg_char < redisCommand.argsize }
  action arg_add_char {
    redisCommand.Args[redisCommand.cur_arg][redisCommand.cur_arg_char] = fc;
    redisCommand.cur_arg_char++;
  }

  redis_argnum = '*' ( digit @argnum_add_digit )+ '\r\n';
  redis_argsize = '$' @argsize_reset ( digit @argsize_add_digit )+ '\r\n';
  redis_arg = (any when test_arg_len @arg_add_char)+ '\r\n';
  redis_cmd = redis_argnum @args_init ( redis_argsize @arg_init redis_arg )+;

  main := redis_cmd;
}%%

%% write data;

func redis_parser_exec(data string) (redisCommand *RedisCommand, err error){
  cs = 0;
  p := 0;
  pe := len(data)
  redisCommand = &RedisCommand{argnum: 0,argsize: 0,cur_arg: 0,cur_arg_char: 0}
  %% write init;
  %% write exec;
  if (cs == RedisParser_error) {
    return nil, errors.New("RedisParser_error")
  } else if (cs < RedisParser_first_final){
    return nil, errors.New("RedisParser_first_final")
  }
  return redisCommand,nil
}

func notifyClients(rediscommand_ch <-chan RedisCommand, es eventsource.EventSource) {
    for{
        select {
            case command := <- rediscommand_ch:
                b, err := json.Marshal(command)
                if err != nil {
                    fmt.Println("error:", err)
                } else {
                    es.SendEventMessage(string(b),"","")
                }
        }
    }
}

func setupEventSource(rediscommand_ch <-chan RedisCommand) {
    es := eventsource.New(nil,nil)
    defer es.Close()
    go notifyClients(rediscommand_ch, es)
    http.Handle("/redis", es)
    http.Handle("/", http.FileServer(http.Dir("./ui/dist")))
    err := http.ListenAndServe(":12345", nil)
    if err != nil {
        panic("ListenAndServe: " + err.Error())
    }
}

func setupPcap(device *string, port *string, rediscommand_ch chan<- RedisCommand) {
    var h *pcap.Pcap
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

    err = h.SetFilter("dst port "+*port)
    if err != nil {
        fmt.Println("set filter failed")
        return
    }

    for {
        pkt := h.Next()
        if pkt == nil {
            continue
        }
        pkt.Decode()
        if s := string(pkt.Payload); s != "" {
            fmt.Println(s)
            rediscommand,err := redis_parser_exec(s)
            if (err != nil) {
                fmt.Println(err)
            } else {
                if pkt.Type == pcap.TYPE_IP {
                  iphdr := pkt.Headers[0].(*pcap.Iphdr)
                  rediscommand.Ipaddr = []byte(iphdr.SrcAddr())
                  fmt.Println(rediscommand)
                }
                rediscommand_ch <- *rediscommand
            }
        }
    }
}

func main(){
	var device *string = flag.String("d", "", "device")
	var port *string = flag.String("p", "6379", "port")
    flag.Parse()


    rediscommand_ch := make(chan RedisCommand)

    go setupEventSource(rediscommand_ch)
    setupPcap(device,port,rediscommand_ch)
}
