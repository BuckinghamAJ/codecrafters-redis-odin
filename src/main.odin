package main

import "core:fmt"
import "core:net"

Redis_Error :: union {
	net.TCP_Recv_Error,
	net.Accept_Error
}

receive :: proc(socket: net.TCP_Socket, buf: ^[]byte) -> (err: net.TCP_Recv_Error) {

	br := net.recv_tcp(socket, buf^) or_return
	fmt.printfln("bytes_received: %d", br)

	if br == 0 do return .Connection_Closed

	fmt.printfln("%q", string(buf^[:br]))

	return nil
}

redis_entry :: proc(listen_socket: net.TCP_Socket) -> (err: Redis_Error){
    client_socket, client_endpoint := net.accept_tcp(listen_socket) or_return
    pong := "+PONG\r\n"

    buf := make([]byte, 1024, context.temp_allocator)

    for {
	    receive(client_socket, &buf) or_break
	    net.send_tcp(client_socket, buf=transmute([]byte)pong)
    }

    return nil
}

main :: proc (){
	listen_socket, listen_err := net.listen_tcp(net.Endpoint{
        port = 6379,
        address = net.IP4_Loopback
    })
	if listen_err != nil {
        fmt.panicf("%s", listen_err)
    }

	err := redis_entry(listen_socket)
	if err != nil {
		fmt.panicf("%s", err)
	}

	free_all(context.temp_allocator)
}
