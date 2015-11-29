open Core.Std
open Async.Std

module Azmq = Async_zmq.Socket

let address = "inproc://test"

let run_req s =
  Azmq.send s "payload" >>= fun () ->
  Log.Global.info "Sent req payload";
  Azmq.recv s >>| function
  | "ok" -> Log.Global.info "terminate success"
  | wrong -> failwithf "failed test: %s" wrong ()

let run_rep s =
  Azmq.recv s >>= function
  | "payload" ->
    Log.Global.info "Received correct payload";
    Azmq.send s "ok" >>| (fun () -> Log.Global.info "Sent ok")
  | wrong -> failwithf "unexpected payload: %s" wrong ()

let run () =
  let z = ZMQ.Context.create () in
  let req_sock = ZMQ.Socket.create z ZMQ.Socket.req in
  let req = Azmq.of_socket req_sock in
  let rep_sock = ZMQ.Socket.create z ZMQ.Socket.rep in
  let rep = Azmq.of_socket rep_sock in
  Log.Global.info "Connecting to %s" address;
  ZMQ.Socket.connect req_sock address;
  Log.Global.info "Binding to %s" address;
  ZMQ.Socket.bind rep_sock address;
  Monitor.protect (fun () ->
    Log.Global.info "Starting test";
    Deferred.all_ignore [run_req req; run_rep rep]
  ) ~finally:(fun () ->
    Log.Global.info "Cleaning up";
    ZMQ.Context.terminate z;
    Azmq.close req >>= fun () ->
    Azmq.close rep
  )

let () =
  let spec = Command.Spec.empty in
  let cmd = Command.async_basic ~summary:"test_req_rep" spec run in
  Command.run cmd
