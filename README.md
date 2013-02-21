Async-zmq
==========================

Warning
-------
Async-zmq is alpha quality for now.

Installation
-------
```
oasis setup
ocaml setup.ml -configure
ocaml setup.ml -all
ocaml setup.ml -install
```

Credits
-------
[lwt-zmq](https://github.com/hcarty/lwt-zmq.git ) by H. Carty. For now async-zmq is almost a carbon copy
of lwt-zmq (you could probably write a functor over these). Improvements
to make it more idiomatic w.r.t async are coming however.

