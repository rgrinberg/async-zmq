module Socket : sig
  open Async.Std
  (** An Async-wrapped zeromq socket *)
  type 'a t

  (** [of_socket s] wraps the zeromq socket [s] for use with Async *)
  val of_socket : 'a ZMQ.Socket.t -> 'a t Deferred.t

  (** [recv socket] waits for a message on [socket] without blocking other Async threads *)
  val recv : 'a t -> string Async_core.Deferred.t

  (** [send socket] sends a message on [socket] without blocking other Async threads *)
  val send : 'a t -> string -> unit Async_core.Deferred.t
end
