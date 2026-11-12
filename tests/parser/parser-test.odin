package parser

import "core:reflect"
import "core:log"
import "core:testing"
import redis "../../src"

value_equal :: proc(a, b: redis.Value) -> bool {
	switch av in a {
	case redis.Simple_String:
		bv, ok := b.(redis.Simple_String)
		return ok && av == bv
	case redis.Integer:
		bv, ok := b.(redis.Integer)
		return ok && av == bv
	case redis.Bulk_String:
		bv, ok := b.(redis.Bulk_String)
		return ok && av == bv
	case redis.Array:
		bv, ok := b.(redis.Array)
		if !ok || len(av) != len(bv) do return false
		for i in 0..<len(av) {
			if !value_equal(av[i], bv[i]) do return false
		}
		return true
	}

	return false
}

expect_value_eq :: proc(t: ^testing.T, value, expected: redis.Value, loc := #caller_location) -> bool {
	ok := value_equal(value, expected)
	if !ok {
		log.errorf("expected %v(%w), got %v(%w)",
			reflect.union_variant_typeid(expected), expected,
			reflect.union_variant_typeid(value), value,
			location = loc)
	}
	return ok
}

@(test)
test_parser :: proc(t: ^testing.T){
	TestCase :: struct {
		msg: string,
		expected: redis.Value
	}

	cases := []TestCase{
		{msg = "+OK\r\n", expected = redis.Simple_String("OK")},
		{msg = ":1000\r\n", expected = redis.Integer(i64(1000))},
		{msg = ":-1000\r\n", expected = redis.Integer(i64(-1000))},
		{msg = "$5\r\nhello\r\n", expected = redis.Bulk_String{"hello", false}},
		{msg = "$0\r\n\r\n", expected = redis.Bulk_String{"", false}},
		{msg = "$-1\r\n", expected = redis.NULL_BULK_STRING},
		{msg = "*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n",
			expected = redis.Array{redis.Bulk_String{"hello", false}, redis.Bulk_String{"world", false}}},
		{msg = "*3\r\n:1\r\n:2\r\n:3\r\n",
			expected = redis.Array{redis.Integer(i64(1)), redis.Integer(i64(2)), redis.Integer(i64(3))}},

	}

	for tc in cases{
		p := redis.Parser{
			buf = tc.msg
		}
		res, err := redis.parse(&p)
		expect_value_eq(t, res, tc.expected)
	}
}
