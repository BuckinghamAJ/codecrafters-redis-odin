package main

import "core:log"
import "core:strconv"
import "core:strings"
Simple_String :: distinct string
Integer :: distinct i64
Array :: distinct []Value

Bulk_String :: struct {
	data: string,
	null: bool,
}

NULL_BULK_STRING :: Bulk_String {"", true}

Simple_Error :: struct {
	kind : string,
	msg  : string
}

Value :: union {
	Simple_String,
	Integer,
	Bulk_String,
	Array
}

Parser :: struct {
	buf : string,
	pos: int
}

Parser_Error :: enum {
	Incomplete,
	Bad_Prefix,
	Bad_Integer
}

read_line :: proc(p: ^Parser) -> (line: string, bool: bool){
	rest := p.buf[p.pos:]
	idx := strings.index_any(rest, "\r\n")
	if idx < 0 do return "", false
	p.pos += idx + 2
	return  rest[1:idx], true
}

@(require_results)
parse :: proc(p: ^Parser, allocator := context.allocator) -> (val: Value, err: Parser_Error) {
	pos : int
	if p.pos >= len(p.buf) do return nil, .Incomplete

	prefix := p.buf[p.pos]
	switch prefix {
	case '+': //+OK\r\n
		line, ok := read_line(p)
		if !ok do return nil, .Incomplete

		return Simple_String(line), nil
	case ':': //:[<+|->]<value>\r\n
		line, ok := read_line(p)
		if !ok do return nil, .Incomplete

		v, vok := strconv.parse_int(line)
		if !vok do return nil, .Bad_Prefix
		return Integer(i64(v)), nil
	case '$':
		length_str, ok := read_line(p)
		if !ok do return nil, .Incomplete

		length, lok := strconv.parse_int(length_str)
		if !lok do return nil, .Bad_Prefix

		if length < 0 do return NULL_BULK_STRING, nil

		data := p.buf[p.pos:p.pos+length]
		p.pos += length + 2
		return Bulk_String{data, false}, nil

	case '*': //*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n
		elements_str, elem_ok := read_line(p)
		if !elem_ok do return nil, .Incomplete

		num_of_elements, ok := strconv.parse_int(elements_str)
		if !ok do return nil, .Bad_Integer

		array := make(Array, num_of_elements, allocator)
		for i in 0..<num_of_elements {
			elem, err := parse(p, allocator)
			log.info("Element: ", elem)
			array[i] = elem
		}

		return array, nil
	}

	return nil, .Bad_Prefix
}


resp :: proc(msg: string)  {
	p := Parser{buf = msg}
	val, err := parse(&p)
	defer {
		if v, ok := val.(Array); ok {
			delete(v)
		}
	}
}
