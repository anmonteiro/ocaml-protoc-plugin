# Ocaml protoc plugin
[![Main workflow](https://github.com/andersfugmann/ocaml-protoc-plugin/actions/workflows/workflow.yml/badge.svg)](https://github.com/andersfugmann/ocaml-protoc-plugin/actions/workflows/workflow.yml)

The goal of Ocaml protoc plugin is to create plugin for
the google protobuf compiler (`protoc`) to generate Ocaml types and
serialization and de-serialization functions from a `.proto`
file. Ocaml-protoc-plugin aims to be a fully compliant implementation
of the google protobuffer standard and guidelines.

The main features include:
* Messages are mapped to idiomatic OCaml types, using modules
* Support service descriptions
* proto3 compliant
* proto2 compliant
* Supports includes
* Supports proto2 extensions
* Builtin support for google well known types
* Configurable annotations for all generated types

## Comparison with other OCaml protobuf handlers.

| Feature           | ocaml-protoc-plugin | ocaml-protoc  | ocaml-pb            |
| -------           | ------------------- | ------------  | ---------------     |
| Ocaml types       | Supported           | Supported     | Defined runtime[^1] |
| Service endpoints | Supported           | Supported     | N/A                 |
| proto3            | Supported           | Supported[^3] | Supported           |
| proto2            | Supported           | Supported[^3] | Supported           |
| proto2 extends    | Supported           | Ignored       | Supported           |
| proto2 groups     | Not supported[^2]   | Ignored       | ?                   |
| json mappings     | Supported           | Supported     | ?                   |

[^1] Ocaml-bp has a sister project `Ocaml-bp-plugin` which emit
Ocaml-pb definitions from a `.proto`. The plugin parses files are proto2
Ocaml type definitions (all fields are option types), and repeated
fields are not packed by default.

[^2] Groups has been deprecated by google and should not be used.

[^3] `ocaml_protoc` will always transmit all fields that are not
marked optional, and does not *strictly* comply to the protobuf
specification.



## Types
Basic types are mapped trivially to Ocaml types:

Primitive types:

| Protobuf Type                                | Ocaml type       |
| -------------                                | ----------       |
| int32, int64, uint32, uint64, sint32, sint64 | int[^5]          |
| fixed64, sfixed64, fixed32, sfixed32         | int32, int64[^5] |
| bool                                         | bool             |
| float, double                                | float            |
| string                                       | string           |
| bytes                                        | bytes            |

[^5] The plugin supports changing the type for scalar types to
int/int64/int32. See options section below.

A message <name> declaration is compiled to a module <Name> with a record type
`t`. Single field messages are mapped not wrapped in a record and messages without any fields are mapped to unit.

Packages are trivially mapped to modules.
Included proto files (`<name>.proto`) are assumed to have been compiled
to `<name>.ml`, and types in included proto files are referenced by
their fill name.

Compound types are mapped like:

| Protobuf Type | Ocaml type                                                              |
| ------------- | ----------                                                              |
| oneof         | Polymorphic variants:  `[ Field1 of fieldtype1, Field1 of fieldtype2 ]` |
| repeated 'a   | 'a list                                                                 |
| message       | message option                                                          |
| enum          | Abstract data types: `` Enum1, Enum2, Enum3 ``                          |
| map<'a, 'b>   | Associative list: ('a * 'b) list                                        |


## Proto2 type support
The specification for proto2 states that when deserializing a message,
fields which are not transmitted should be set the the default value
(either 0, or the value of the default option).

However, It seems to be the norm for proto2, that it should
be possible to determine if a field was transmitted or not. Therefore
all non-repeated fields in proto2 are option types - unless the field has a
default value, or is a required field.

The proto2 specification states that no default values should be
transmitted. However, as it is normal to be able to identify if a
field has been transmitted or not, only fields with an explicit
default value will be omitted when the value for the field matches the
default value.

## Invocation
If the plugin is available in the path as `protoc-gen-ocaml`, then you
can generate the Ocaml code by running

```
  protoc --ocaml_out=. --ocaml_opt=<options> file.proto
```

## Options

*Options* control the code/types generated.

| Option               | Description                                                     | Example                      | Default |
| -----------          | ------------------------------                                  | -----------------------      | ------- |
| annot                | Type annotations.                                               | `annot=[@@deriving show]`    | ""      |
| debug                | Enable debugging                                                | `debug`                      | Not set |
| open                 | Add open at top of generated files. May be given multiple times | `open=Base.Sexp`             | []      |
| int64\_as\_int       | Map \*int64 types to int instead of `int64`                     | `int64_as_int=false`         | true    |
| int32\_as\_int       | Map \*int32 types to int instead of `int32`                     | `int32_as_int=false`         | true    |
| fixed\_as\_int       | Map \*fixed\* types to `int`                                    | `fixed_as_int=true`          | false   |
| singleton\_record    | Messages with only one field will be wrapped in a record        | `singleton_records=true`     | false   |


Parameters are separated by `;`

If `protoc-gen-ocaml` is not located in the path, it is possible to
specify the exact path to the plugin:

```
protoc --plugin=protoc-gen-ocaml=../plugin/ocaml-protocol-plugin.exe --ocaml_out=. <file>.proto
```

### Json serialization and deserialization
Ocaml-proto-plugin can serialize and deserialize to/from json, using
`Yojson.Basic.t` type. Using the function `to_json`, `from_json` and
`from_json_exn` simmilar to regular protobuffer serialization and
deserialization.

Json serialization can be controlled using optional arguments:

```ocaml
val to_json: ?enum_names:bool -> ?json_names:bool -> ?omit_default_values:bool -> t -> Yojson.Basic.t
```

| argument  | comment  | default  |
|---|---|---|
| `enum_names`  | By default enum names are used when serializing to json. Setting to false will use enum values instead | true  |
| `json_names`  | By default Json will use camelCase names for fields. Setting to false will use the names as defined in the proto definition file | true  |
| `omit_default_values` | By default json will not serialize default values to reduce size. Setting to false will for all values to be emitted to the json file. | true |

Json deserialization will accept json constructed with any combination
of the values.

### Older versions of protoc
It seems that the `--ocaml_opt` flag may not be supported by older
versions of the proto compiler. As an alternative, options can also be
passed with the `--ocaml_out` flag:

```
protoc --plugin=protoc-gen-ocaml=../plugin/ocaml.exe --ocaml_out=annot=debug;[@@deriving show { with_path = false }, eq]:. <file>.proto
```
## Mangle generated names
Idiomatic protobuf names are somewhat alien to
Ocaml. `Ocaml_protoc_plugin` has an option to mangle protobuf names
into somewhat more Ocaml idiomatic names. When this option is set (see
below), names are mangled to snake case as described in the table
below:

| Protobyf type | Protobuf name            | Ocaml name               |
|:--------------|:-------------------------|:-------------------------|
| package       | `CapitalizedSnakeCase`   | `Capitalized_snake_case` |
| message       | `CapitalizedSnakeCase`   | `Capitalized_snake_case` |
| field         | `lowercased_snake_case`  | `lowercased_snake_case`  |
| oneof name    | `lowercased_snake_case`  | `lowercased_snake_case`  |
| oneof field   | `capitalized_snake_case` | `Capitalized_snake_case` |
| enum          | `CAPITALIZED_SNAKE_CASE` | `Capitalized_snake_case` |
| service name  | `CapitalizedSnakeCase`   | `Capitalized_snake_case` |
| rpc name      | `LowercasedSnakeCase`    | `lowercased_snake_case`  |

`protoc` cannot guarantee that names do not clash when mangling is
enabled. If a name clash is detected (eg. `SomeMessage` and
`some_message` exists in same file) an apostrophe is appended to the
name to make sure names are unique.

The algorithm for converting CamelCased names to snake_case is done by
injecting an underscore between any lowercase and uppercase character
and then lowercasing the result.

### Setting mangle option
Name mangling option can only be controlled from within the protobuf
specification file. This is needed as protobuf files may reference each
other and it its important to make sure that included names are
referenced correctly across compilation units (and invocations of
protoc).

To set the option use:
```protobuf
// This can be placed in a common file and then included
import "google/protobuf/descriptor.proto";
message options { bool mangle_names = 1; }
extend google.protobuf.FileOptions {
    options ocaml_options = 1074;
}

// This option controls name generation. If true names are converted
// into more ocaml ideomatic names
option (ocaml_options) = { mangle_names:true };

// This message will be mapped to module name My_proto_message
message MyProtoMessage { }
```

### Deprecation annotations in proto files
Protobug specification (.proto file) allow for deprecating *files*,
*enums*, *enum values*, *messages*, *message fields*, *services* and
*methods*.

These deprecations are kept in the ocaml mapping to generate
[alerts](https://ocaml.org/manual/alerts.html) for alert category
'protobuf'.

Alerts are automatically enabled as warnings. To disable deprecation
alerts, either add the compiler flag `-alert -protobuf`, or though ocaml
annotations e.g. by adding `[@@@ocaml.alert "-protobuf"]` to the top
of a file.


## Using dune
Below is a dune rule for generating code for `test.proto`. The
`google_include` target is used to determine the base include path for
google protobuf well known types.
```
(rule
 (targets google_include)
 (action (with-stdout-to %{targets}
          (system "pkg-config protobuf --variable=includedir"))))

(rule
 (targets test.ml)
 (deps
  (:proto test.proto))
 (action
  (run protoc -I %{read-lines:google_include} -I .  "--ocaml_opt=annot=[@@deriving show { with_path = false }, eq]" --ocaml_out=. %{proto})))
```

## Service interface
Service interfaces create a module with values that just references
the request and reply pair. These binding can then be used with
function in `Protobuf.Service`.

The call function will take a `string -> string` function, which
implement message sending -> receiving.

The service function is a `string -> string` function which takes a
handler working over the actual message types.

## Proto2 extensions
Proto2 extensions allows for messages to be extended. For each
extending field, the plugin create a module with a get and set
function for reading/writing extension fields.

Below is an example on how to set and get extension fields


```protobuf
// file: ext.proto
syntax = "proto2";
message Foo {
  required uint32 i = 1;
  extensions 100 to 200;

}
extend Foo {
  optional uint32 bar = 128;
  optional string baz = 129;
}
```

```ocaml
(* file: test.ml *)

open Extensions

(* Set extensions *)
let _ =
  let foo = Foo.{ i = 31; extensions' = Ocaml_protoc_plugin.Extensions.default } in
  let foo_with_bar = Bar.set foo (Some 42) in
  let foo_with_baz = Baz.set foo (Some "Test String") in
  let foo_with_bar_baz = Baz.set foo_with_bar (Some "Test String") in

  (* Get extensions *)
  let open Ocaml_protoc_plugin.Result in
  Bar.get foo_with_bar >>= fun bar ->
  Baz.get foo_with_baz >>= fun baz ->
  assert (bar = Some 42);
  assert (baz = Some "Test String");
  Bar.get foo_with_bar_baz >>= fun bar' ->
  Baz.get foo_with_bar_baz >>= fun baz' ->
  assert (bar' = Some 42);
  assert (baz' = Some "Test String");
  return ()

```
Extensions are replaced by proto3 `Any` type, and use is discouraged.

## Proto3 Any type
No special handling of any type is supported, as Ocaml does not allow
for runtime types, so any type must be handled manually by
serializing and deserializing the embedded message.

## Proto3 Optional fields
Proto3 optional fields are handled in the same way as proto2 optional
fields; The type is an option type, and always transmissted when set.

## Imported protofiles
The generated code assumes that imported modules (generated from proto
files) are available in the compilation scope. If the modules
generated from imported protofiles resides in different a different
scope (e.g. is compiled with `wrapped true`, they need to be made
available by adding parameter `open=<module name>` to make the modules
available for the compilation.

### Google Well know types
Protobuf distributes a set of [*Well-Known
types*](https://developers.google.com/protocol-buffers/docs/reference/google.protobuf).
`ocaml-protoc-plugin` installs compiled versions of these. These can
be used by linking with the package `ocaml-protoc-plugin.google_types`, and adding
option `open=Google_types` to the list of parameters

The distributed google types are compiled using default parameters,
i.e. without any ppx annotations.

If you want to change this, or add type annotations, you can copy the
[dune](https://github.com/andersfugmann/ocaml-protoc-plugin/tree/main/src/google_types/dune)
from the distribution to your own project, and make alterations
there. See the [echo\_deriving](https://github.com/andersfugmann/ocaml-protoc-plugin/tree/main/examples/echo_deriving)
example on how to do this.

# Example

`test.proto`
```protobuf
syntax = "proto3";
message Address {
  enum Planet {
    Earth = 0; Mars  = 1; Pluto = 2;
  }
  string street = 1;
  uint64 number = 2;
  Planet planet = 3;
}

message Person {
  uint64 id       = 1;
  string name     = 2;
  Address address = 3;
}
```

`$ protoc --ocaml_out=. test.proto`

Generates a file `test.ml` with the following signature:

```ocaml
module Address : sig
  module rec Planet : sig
    type t = Earth | Mars | Pluto
    val to_int: t -> int
    val from_int: int -> t Protobuf.Deserialize.result
  end
  val name': unit -> string
  type t = {
    street: string;
    number: int;
    planet: Planet.t;
  }
  val make: ?street:string ?number:int ?planet:Planet.t -> unit -> t
  val to_proto: t -> Protobuf.Writer.t
  val from_proto: Protobuf.Reader.t -> (t, Protobuf.Deserialize.error) result
end
module Person : sig
  val name': unit -> string
  type t = {
    id: int;
    name: string;
    address: Address.t option;
  }
  val make: ?id:int ?name:string ?planet:Address.t -> unit -> t
  val to_proto: t -> Protobuf.Writer.t
  val from_proto: Protobuf.Reader.t -> (t, Protobuf.Deserialize.error) result
end = struct
```

Note that if `test.proto` had a package declaration such as `package testing`,
the modules `Address` and `Person` listed above would be defined as sub-modules
of a top-level module `Testing`.

The function `make` allows the user to create message without
specifying all (or any) fields. Using this function will allow users
to add fields to message later without needing to modify any code, as
new fields will be set to default values.

`Protobuf.Reader` and `Protobuf.Writer` are used then reading or
writing protobuf binary format. Below is an example on how to decode a message
and how to read a message.

```ocaml
let string_of_planet = function
  | Address.Earth -> "earth"
  | Mars -> "mars"
  | Pluto -> "pluto"
in

let read_person binary_message =
  let reader = Protobuf.Reader.create binary_message in
  match Person.from_proto reader in
  | Ok Person.{ id; name; address = Some Address { street; number; planet } } ->
    Printf.printf "P: %d %s - %s %s %d\n" id name (string_of_planet planet) street number
  | Ok Person.{ id; name; address = None } ->
    Printf.printf "P: %d %s - Address unknown\n" id name
  | Error _ -> failwith "Could not decode"
```

More examples can be found under
[examples](https://github.com/andersfugmann/ocaml-protoc-plugin/tree/main/examples)

# Benchmarks

ocaml-protoc-plugin has been optimized for speec, and is comparable [ocaml-protoc](https://github.com/mransan/ocaml-protoc)

Numbers below shows benchmark comparing encoding and decoding speed to
`ocaml-protoc`. The benchmark is run with flambda settings: `-O3 -unbox-closures
-remove-unused-arguments -rounds 3 -inline 100.00 -inline-max-depth 3
-inline-max-unroll 3`. Benchmarks are made on a Intel i5, i5-5257U CPU
@ 2.70GHz, using ocaml switch `5.1.1+flambda`

| name | ocaml-protoc-plugin | ocaml-protoc | ratio |
|  --  |          --         |       --     |  --   |
| bench.M/Decode | 146619.1443 ns/run | 143509.5405 ns/run | 1.021 |
| bench.M/Encode | 119456.6236 ns/run | 161231.8065 ns/run | .740 |
| int64.M/Decode | 25.8114 ns/run | 26.1589 ns/run | .986 |
| int64.M/Encode | 57.3628 ns/run | 36.3365 ns/run | 1.578 |
| float.M/Decode | 27.1202 ns/run | 25.8015 ns/run | 1.051 |
| float.M/Encode | 58.9275 ns/run | 35.1229 ns/run | 1.677 |
| string.M/Decode | 46.2468 ns/run | 41.0179 ns/run | 1.127 |
| string.M/Encode | 80.5362 ns/run | 49.1781 ns/run | 1.637 |
| enum.M/Decode | 28.3250 ns/run | 28.4345 ns/run | .996 |
| enum.M/Encode | 61.7117 ns/run | 38.5143 ns/run | 1.602 |
| empty.M/Decode | 11.0939 ns/run | 9.1665 ns/run | 1.210 |
| empty.M/Encode | 8.4814 ns/run | 24.2034 ns/run | .350 |
| int64_list.M/Decode | 15025.3175 ns/run | 15060.5859 ns/run | .997 |
| int64_list.M/Encode | 10457.3438 ns/run | 11916.0341 ns/run | .877 |
| float_list.M/Decode | 13918.2012 ns/run | 12857.0192 ns/run | 1.082 |
| float_list.M/Encode | 8757.9816 ns/run | 12542.1849 ns/run | .698 |
| string_list.M/Decode | 47648.7843 ns/run | 38610.4188 ns/run | 1.234 |
| string_list.M/Encode | 40314.6457 ns/run | 34202.1095 ns/run | 1.178 |

# Acknowledgements
This work is based on
[issuu/ocaml-protoc-plugin](https://github.com/issuu/ocaml-protoc-plugin).
Thanks to [Issuu](https://issuu.com) who initially developed this library/plugin.

Thanks to all contributers:
* Anders Fugmann <anders@fugmann.net>
* Andreas Dahl <andreas@hrdahl.dk>
* Dario Teixeira <dte@issuu.com>
* Kate <kit.ty.kate@disroot.org>
* Martin Slota <msl@issuu.com>
* Nymphium <s1311350@gmail.com>
* Rauan Mayemir <rauan@mayemir.io>
* Tim McGilchrist <timmcgil@gmail.com>
* Virgile Prevosto <virgile.prevosto@m4x.org>
* Wojtek Czekalski <me@wczekalski.com>
