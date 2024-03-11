module Local : sig
  type t
  val init: unit -> t
  val get_unique_name: t -> string -> string
end

type t
val init : params:Parameters.t -> Spec.Descriptor.Google.Protobuf.FileDescriptorProto.t list -> t

val for_descriptor: params:Parameters.t -> t -> Spec.Descriptor.Google.Protobuf.FileDescriptorProto.t -> t

(** Push an identifier to the current scope *)
val push : t -> string -> t

(** Get the module name of a proto file *)
val module_name_of_proto: ?package:string -> string -> string

(** The import module name - Must be globally unique *)
val import_module_name: string

(** Get the ocaml name of the given proto type name, based on the current scope *)
val get_scoped_name : ?postfix:string -> t -> string option -> string

(** Get the ocaml name of the default enum *)
val get_scoped_enum_name : t -> string option -> string

(** Get the ocaml name of the given proto type name, based on the current scope *)
val get_name : t -> string -> string

(** Get the ocaml name of the given proto type name, based on the current scope *)
val get_name_exn : t -> string option -> string

(** Get the package name. This function assumes callee is in service scope *)
val get_package_name : t -> string option

(** Tell if the type pointed to by the current scope is part of a cycle. *)
val is_cyclic: t -> bool

(** Test is the options specify name mangling *)
val has_mangle_option: Spec.Descriptor.Google.Protobuf.FileOptions.t option -> bool

(** Get stringified version of the current proto path *)
val get_proto_path: t -> string
