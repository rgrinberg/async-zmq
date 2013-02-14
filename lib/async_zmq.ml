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
    (Fd.Kind.infer_using_stat fd) >>| begin fun kind ->
      { socket; fd=(Fd.create kind fd (Info.of_string "bs")) }
    end

  let zmq_event socket ~f =
    let open ZMQ.Socket in
    try begin match events socket with
              | No_event -> raise Retry
              | Poll_in | Poll_out | Poll_in_out -> f socket end
    with | ZMQ.ZMQ_exception (ZMQ.EAGAIN, _) -> raise Retry
         | ZMQ.ZMQ_exception (ZMQ.EINTR, _) -> raise Break_event_loop

  (* TODO : fix this, extremely hairy for now *)
  let wrap f {socket;fd} =
    let f x = return (f x) in (* how to do liftM properly? *)
    let io_loop () =
      In_thread.syscall_exn ~name:"events" (fun () -> zmq_event socket ~f)
    in
    let rec idle_loop () =
      let open ZMQ in
      Monitor.try_with (fun () -> f socket) >>= function
        | Ok x -> return x
        | Error (ZMQ_exception (EINTR, _)) -> idle_loop ()
        | Error (ZMQ_exception (EINTR, _)) -> begin
          let rec inner_loop () =
            Monitor.try_with io_loop >>= function
              | Error(Break_event_loop) -> idle_loop ()
              | Error(Retry) -> inner_loop ()
              | Ok x -> x
          in inner_loop ()
        end
    in idle_loop ()

  let recv s =
    wrap (fun s -> ZMQ.Socket.recv ~opt:ZMQ.Socket.R_no_block s) s

  let send s m =
    wrap (fun s -> ZMQ.Socket.send ~opt:ZMQ.Socket.S_no_block s m) s
end

