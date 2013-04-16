open Async.Std
open Core.Std
module Raw = struct
  exception Break_event_loop
  exception Retry

  type 'a t = {
    socket : 'a ZMQ.Socket.t;
    fd : Async.Std.Fd.t; }

  let of_socket socket = 
    let fd = ZMQ.Socket.get_fd socket in
    { socket; fd=(Fd.create (Fd.Kind.Socket `Bound) fd (Info.of_string "<zmq>"))}

  let zmq_event socket ~f =
    let open ZMQ.Socket in
    try begin match events socket with
      | No_event -> raise Retry
      | Poll_in | Poll_out | Poll_in_out -> f socket end
    with | ZMQ.ZMQ_exception (ZMQ.EAGAIN, _) -> raise Retry
         | ZMQ.ZMQ_exception (ZMQ.EINTR, _) -> raise Break_event_loop

  (* TODO : fix this, extremely hairy for now *)
  let wrap f {socket;_} =
    let f x = In_thread.syscall_exn ~name:"<wrap>" (fun () -> f x) in
    let io_loop () =
      In_thread.syscall_exn ~name:"<events>" (fun () -> zmq_event socket ~f)
    in
    let rec idle_loop () =
      let open ZMQ in
      Monitor.try_with ~extract_exn:true ~name:"<idle_loop>"
        (fun () -> f socket) >>= function
      | Ok x -> return x
      | Error (ZMQ_exception (EINTR, _)) -> idle_loop ()
      | Error (ZMQ_exception (EAGAIN, _)) -> begin
          let rec inner_loop () =
            Monitor.try_with ~extract_exn:true ~name:"<io_loop>" io_loop >>= function
            | Ok x -> x
            | Error Break_event_loop -> idle_loop ()
            | Error Retry -> inner_loop ()
            | Error x -> raise x (* necessary? *)
          in inner_loop ()
        end
      | Error x -> raise x (* is this necessary? *)
    in idle_loop ()

  let recv s =
    wrap (fun s -> ZMQ.Socket.recv ~opt:ZMQ.Socket.R_no_block s) s

  let send s m =
    wrap (fun s -> ZMQ.Socket.send ~opt:ZMQ.Socket.S_no_block s m) s
end
