package redis_protocol

import "testing"

func TestParse(t *testing.T) {
	cases := []struct {
		in           string
		expect_error bool
	}{
		{"*4\r\n$5\r\nSETEX\r\n$6\r\ne:ntry\r\n$2\r\n30\r\n$2\r\n\r\n", true},
		{"*4\r\n$5\r\nSETEX\r\n$6\r\ne:ntry\r\n$2\r\n30\r\n$0\r\n\r\n", false},
	}
	for _, c := range cases {
		_, err := Parse(c.in)
		if c.expect_error && err == nil {
			t.Errorf("Parse(%q), expected an error", c.in)
		}
		if !c.expect_error && err != nil {
			t.Errorf("Parse(%q), did not expect an error %q", c.in, err)
		}
	}
}
