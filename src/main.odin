package main

import "core:sys/posix"
import "core:sys/kqueue"
import "core:fmt"
import "core:net"

Redis_Error :: union {
	net.TCP_Recv_Error,
	net.Accept_Error
}

receive :: proc(socket: net.TCP_Socket, buf: []byte) -> (bytes_received: int, err: net.TCP_Recv_Error) {

	br := net.recv_tcp(socket, buf) or_return
	fmt.printfln("bytes_received: %d", br)

	if br == 0 do return 0, .Connection_Closed

	fmt.printfln("%q", string(buf[:br]))

	return br, nil
}

redis_entry :: proc(listen_socket: net.TCP_Socket) -> (err: Redis_Error){

	client_socket, client_endpoint := net.accept_tcp(listen_socket) or_return
    pong := "+PONG\r\n"

    buf : [1024]byte

    for {
	    n := receive(client_socket, buf[:]) or_break
		message := buf[:n]
	    net.send_tcp(client_socket, buf=transmute([]byte)pong)
    }

    return nil
}

main :: proc (){
	clients = make(map[uintptr]Client)
	defer delete(clients)

	kq, err := kqueue.kqueue()
	if err != .NONE {
		panic(fmt.tprintfln("Error starting kqueue: %w", err))
	}
	defer posix.close(kq)

	listen_socket, listen_err := net.listen_tcp(net.Endpoint{
        port = 6379,
        address = net.IP4_Loopback
    })
	if listen_err != nil {
        fmt.panicf("%s", listen_err)
    }
	net.set_blocking(listen_socket, false)

	listener_change := kqueue.KEvent{
		ident = uintptr(listen_socket),
		filter = .Read,
		flags = {.Add, .Enable}
	}

	// Registering the listen_socket to the kq
	_, err = kqueue.kevent(kq, {listener_change}, nil, nil)
	if err != .NONE {
		panic(fmt.tprintfln("Error registering event change: %w", err))
	}

	// Event Loop
	events : [64]kqueue.KEvent
	for {
		n, _ := kqueue.kevent(kq, nil, events[:], nil)

		for ev in events[:n]{
			fmt.printfln("event: %v", ev)
			if ev.ident == uintptr(listen_socket) do client_accept(kq, listen_socket)
			else {
				client, ok := &clients[ev.ident]
				if client == nil || !ok {
					fmt.printfln("Not able to find client for %d", ev.ident)
					continue
				}

				if .EOF in ev.flags do client_remove(client)
				else do client_receive_msg(client)

			}
		}
	}

	free_all(context.temp_allocator)
}
