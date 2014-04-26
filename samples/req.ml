open Core.Std
open Async.Std

module AZMQ = Async_zmq.Raw

let req z socket =
  print_endline "created zmq socket...";
  (*AZMQ.of_socket_async socket >>> (fun sock ->*)
  let sock = AZMQ.of_socket socket in
  print_endline "Sending a request";
  upon (AZMQ.send sock "REQUEST: req.ml" >>= (fun _ ->
    print_endline "Request sent. Waiting for a reply";
    AZMQ.recv sock >>= (fun reply ->
      Printf.printf "Received: '%s'" reply;
      return ()
    ))) (fun _ ->
    ZMQ.Socket.close socket;
    ZMQ.Context.terminate z;
    Shutdown.shutdown 0;
    ())

let () = 
  let z = ZMQ.Context.create () in
  let socket = ZMQ.Socket.create z ZMQ.Socket.req in
  ZMQ.Socket.connect socket "tcp://127.0.0.1:5555";
  req z socket; 
  never_returns (Scheduler.go ())

