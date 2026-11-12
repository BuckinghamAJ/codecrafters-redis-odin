package main

import "core:sys/posix"
import "core:sys/kqueue"
import "core:fmt"
import "core:net"

Redis_Error :: union {
	net.TCP_Recv_Error,
	net.Accept_Error
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
