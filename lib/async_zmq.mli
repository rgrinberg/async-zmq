open Core.Std
open Async.Std

(** This module is meant to be as compatible as possible with lwt-zmq. It
    should be straight forward to write a functor over Async_zmq.Raw and
    Lwt_zmq.Socket *)
module Raw : sig
  (** An Async-wrapped zeromq socket *)
  type 'a t with sexp_of

  (** [of_socket s] wraps the zeromq socket [s] for use with Async *)
  val of_socket : 'a ZMQ.Socket.t -> 'a t

  (** [recv socket] waits for a message on [socket] without blocking
      other Async threads *)
  val recv : 'a t -> string Deferred.t

  (** [send socket] sends a message on [socket] without blocking other
      Async threads *)
  val send : 'a t -> string -> unit Deferred.t
end
