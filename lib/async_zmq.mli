(** Almost carbon copy of lwt-zmq. Main difference being is that of_socket is
 * non-blocking in this module *)

module Socket : sig
  open Async.Std

  (** An Async-wrapped zeromq socket *)
  type 'a t

  (** [of_socket_async s] wraps the zeromq socket [s] for use with Async. *)
  (*val of_socket_async : 'a ZMQ.Socket.t -> 'a t Deferred.t*)

  (** [of_socket s k] wraps the zeromq socket [s] with kind [k] for use with Async *)
  val of_socket : 'a ZMQ.Socket.t -> Fd.Kind.t -> 'a t

  (** [recv socket] waits for a message on [socket] without blocking other Async threads *)
  val recv : 'a t -> string Async_core.Deferred.t

  (** [send socket] sends a message on [socket] without blocking other Async threads *)
  val send : 'a t -> string -> unit Async_core.Deferred.t
end
