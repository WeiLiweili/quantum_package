exception AtomError of string

type t = { element : Element.t; charge : Charge.t; coord : Point3d.t; } 

val t_of_sexp : Sexplib.Sexp.t -> t
val sexp_of_t : t -> Sexplib.Sexp.t

val of_string : Units.units -> string -> t
val to_string : Units.units -> t -> string
