package main;
import(
    "errors"
    "fmt"
)

type RedisCommand struct {
  argnum int;
  argsize int;
  cur_arg int;
  cur_arg_char int;
  args [][]byte;
  args_sizes []int;
}

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
    redisCommand.args = make([][]byte,redisCommand.argnum);
    redisCommand.args_sizes = make([]int,redisCommand.argnum);
  }
  action arg_init {
    redisCommand.cur_arg++;
    redisCommand.cur_arg_char = 0;
    redisCommand.args_sizes[redisCommand.cur_arg] = redisCommand.argsize;
    redisCommand.args[redisCommand.cur_arg] = make([]byte,redisCommand.argsize);
  }
  action test_arg_len { redisCommand.cur_arg_char < redisCommand.argsize }
  action arg_add_char {
    redisCommand.args[redisCommand.cur_arg][redisCommand.cur_arg_char] = fc;
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

func main(){
    input := "*3\r\n$3\r\nSET\r\n$5\r\nmykey\r\n$7\r\nmyvalue\r\n"
    sc,err := redis_parser_exec(input)
    if (err != nil) {
        fmt.Println(err)
    } else {
        for _, command := range sc.args {
            fmt.Println(string(command))
        }
    }
}
