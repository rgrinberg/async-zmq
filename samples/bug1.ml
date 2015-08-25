open Core.Std
open Async.Std

module AZMQ = Async_zmq.Socket

let test () =
  let z = ZMQ.Context.create () in
  let socket = ZMQ.Socket.create z ZMQ.Socket.req in
  ZMQ.Socket.connect socket "tcp://127.0.0.1:5555";
  let sock = AZMQ.of_socket socket in
  AZMQ.close sock >>| fun () ->
  ZMQ.Context.terminate z

let () =
  don't_wait_for (test () >>= fun () -> test ());
  never_returns (Scheduler.go ())


