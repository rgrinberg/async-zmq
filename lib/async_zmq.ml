module Socket = struct
  open Core.Std
  open Async.Std

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
  let wrap f {socket;fd} =
    let f x = In_thread.syscall_exn ~name:"<wrap>" (fun () -> f x) in
    let io_loop () =
      In_thread.syscall_exn ~name:"<events>" (fun () -> zmq_event socket ~f)
    in
    let rec idle_loop () =
      let open ZMQ in
      Monitor.try_with ~name:"<idle_loop>" (fun () -> f socket) >>= function
        | Ok x -> return x
        | Error _exn -> begin
            match (Monitor.extract_exn _exn) with
            | ZMQ_exception (EINTR, _) -> idle_loop ()
            | ZMQ_exception (EAGAIN, _) -> begin
              let rec inner_loop () =
                Monitor.try_with ~name:"<io_loop>" io_loop >>= function
                  | Ok x -> x
                  | Error _exn -> begin 
                    match (Monitor.extract_exn _exn) with
                    | Break_event_loop -> idle_loop ()
                    | Retry -> inner_loop ()
                    end
              in inner_loop ()
              end
            end
    in idle_loop ()

  let recv s =
    wrap (fun s -> ZMQ.Socket.recv ~opt:ZMQ.Socket.R_no_block s) s

  let send s m =
    wrap (fun s -> ZMQ.Socket.send ~opt:ZMQ.Socket.S_no_block s m) s
end

