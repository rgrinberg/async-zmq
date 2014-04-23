open Core.Std
open Async.Std

module AZMQ = Async_zmq.Raw

let rep () =
  let z = ZMQ.Context.create () in
  let socket = ZMQ.Socket.create z ZMQ.Socket.rep in
  ZMQ.Socket.bind socket "tcp://127.0.0.1:5555";
  print_endline "created zmq socket...";
  let sock = AZMQ.of_socket socket in
  print_endline "Waiting for a message";
  upon (AZMQ.recv sock >>= (fun msg ->
    Printf.printf "Received: '%s', sending a reply" msg;
    AZMQ.send sock "reply"
  )) (fun () ->
    ZMQ.Socket.close socket;
    Shutdown.shutdown 0; ()
  )

let () = rep (); never_returns (Scheduler.go ())
