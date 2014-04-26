open Core.Std
open Async.Std

module Raw = struct
  exception Break_event_loop with sexp
  exception Retry with sexp

  type 'a t = {
    socket : 'a ZMQ.Socket.t sexp_opaque;
    fd : Fd.t; } with sexp_of, fields

  let to_socket = socket

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

  let wrap (f : _ ZMQ.Socket.t -> _) { socket ; _ } =
    let io_loop () =
      In_thread.syscall_exn ~name:"<wrap>" (fun () ->
        try
          (* Check for zeromq events *)
          match ZMQ.Socket.events socket with
          | ZMQ.Socket.No_event -> raise Retry
          | ZMQ.Socket.Poll_in
          | ZMQ.Socket.Poll_out
          | ZMQ.Socket.Poll_in_out -> f socket
          (* This should not happen as far as I understand *)
          | ZMQ.Socket.Poll_error -> assert false
        with
        (* Not ready *)
        | Unix.Unix_error (Unix.EAGAIN, _, _) -> raise Retry
        (* We were interrupted so we need to start all over again *)
        | Unix.Unix_error (Unix.EINTR, _, _) -> raise Break_event_loop
      )
    in
    let rec idle_loop () =
      (* why are we running things in a monitor here? *)
      try_with ~extract_exn:true (fun () -> return (f socket)) >>= function
      | Ok x -> return x
      | Error (Unix.Unix_error (Unix.EINTR, _, _)) -> idle_loop ()
      | Error (Unix.Unix_error (Unix.EAGAIN, _, _)) ->
        begin try_with ~extract_exn:true io_loop >>= function
        | Ok x -> return x
        | Error Break_event_loop -> idle_loop ()
        | Error x -> raise x
        end
      | Error x -> raise x
    in
    idle_loop ()

  let recv s = wrap (fun s -> ZMQ.Socket.recv ~block:false s) s

  let send s m = wrap (fun s -> ZMQ.Socket.send ~block:false s m) s

  let recv_all s =
    wrap (fun s -> ZMQ.Socket.recv_all ~block:false s) s

  let send_all s parts =
    wrap (fun s -> ZMQ.Socket.send_all ~block:false s parts) s

end
