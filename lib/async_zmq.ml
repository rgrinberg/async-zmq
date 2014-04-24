open Core.Std
open Async.Std

module Raw = struct
  exception Break_event_loop with sexp
  exception Retry with sexp

  type 'a t = {
    socket : 'a ZMQ.Socket.t sexp_opaque;
    fd : Fd.t; } with sexp_of

  let of_socket socket = 
    let fd = 
      Fd.create (Fd.Kind.Socket `Bound)
        (ZMQ.Socket.get_fd socket)
        (Info.of_string "<zmq>")
    in
    { socket; fd; }

  let zmq_event socket ~f =
    let open ZMQ.Socket in
    try begin match events socket with
      | No_event -> raise Retry
      | Poll_in
      | Poll_out
      | Poll_in_out -> f socket
      | Poll_error -> assert false
    end
    with | Unix.Unix_error (Unix.EAGAIN, _, _) -> raise Retry
         | Unix.Unix_error (Unix.EINTR, _, _) -> raise Break_event_loop

  (* TODO : fix this, extremely hairy for now *)
  let wrap f { socket ; _ } =
    let f x = In_thread.syscall_exn ~name:"<wrap>" (fun () -> f x) in
    let io_loop () =
      In_thread.syscall_exn ~name:"<events>" (fun () -> zmq_event socket ~f)
    in
    let rec idle_loop () =
      let open ZMQ in
      try_with ~extract_exn:true ~name:"<idle_loop>"
        (fun () -> f socket) >>= function
      | Ok x -> return x
      | Error (Unix.Unix_error (Unix.EINTR, _, _)) -> idle_loop ()
      | Error (Unix.Unix_error (Unix.EAGAIN, _, _)) -> begin
          let rec inner_loop () =
            try_with ~extract_exn:true ~name:"<io_loop>" io_loop >>=
            function
            | Ok x -> x
            | Error Break_event_loop -> idle_loop ()
            | Error Retry -> inner_loop ()
            | Error x -> raise x (* necessary? *)
          in inner_loop ()
        end
      | Error x -> raise x (* is this necessary? *)
    in idle_loop ()

  let recv s = wrap (fun s -> ZMQ.Socket.recv ~block:false s) s

  let send s m = wrap (fun s -> ZMQ.Socket.send ~block:false s m) s
end
