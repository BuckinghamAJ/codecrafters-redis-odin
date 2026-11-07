package main

import "core:sys/kqueue"
import "core:log"
import "core:fmt"
import "core:net"

Client :: struct {
	socket : net.TCP_Socket,
	endpoint : net.Endpoint,
	fd: uintptr
}

clients : map[uintptr]Client

client_accept :: proc(kq: kqueue.KQ, listen_socket : net.TCP_Socket) {
	client_socket, client_endpoint, err := net.accept_tcp(listen_socket)
	if err != nil {
		panic("Error accepting tcp!")
	}
	net.set_blocking(client_socket, false)

	client_add := kqueue.KEvent{
		ident = uintptr(client_socket),
		filter = .Read,
		flags = {.Add, .Enable}
	}

	_, kerr := kqueue.kevent(kq, {client_add}, nil, nil)
	if kerr != .NONE {
		fmt.printfln("Error registering client add change: %w", kerr)
		return
	}

	clients[uintptr(client_socket)] = Client{
		socket = client_socket,
		endpoint = client_endpoint,
		fd = uintptr(client_socket)
	}


}

client_receive_msg :: proc(client: ^Client) {
 	buf : [1024]byte

  	pong := "+PONG\r\n"

 	n, err := receive(client.socket, buf[:])
 	if err != nil {
		fmt.printfln("Error receving message %s on socket: %d", buf[:], client.socket)

	}
  	message := buf[:n]
   	net.send_tcp(client.socket, buf=transmute([]byte)pong)
}

client_remove :: proc(client: ^Client) {
	delete_key(&clients, client.fd)
	net.close(client.socket)
}
